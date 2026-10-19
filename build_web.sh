#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-build}" in
    build|--check) ;;
    *) echo "Usage: ./build_web.sh [--check]" >&2; exit 1 ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required." >&2; exit 1; }
GODOT_BIN="${GODOT_BIN:-${GODOT:-}}"
if [[ -z "$GODOT_BIN" ]]; then
    for candidate in godot godot4 /Applications/Godot.app/Contents/MacOS/Godot \
        "$HOME/Library/Application Support/Godot/app_userdata/Godots/versions/"Godot_v4_8-*/Godot.app/Contents/MacOS/Godot; do
        if command -v "$candidate" >/dev/null 2>&1; then
            GODOT_BIN="$candidate"
            break
        fi
    done
fi
[[ -n "$GODOT_BIN" ]] && command -v "$GODOT_BIN" >/dev/null 2>&1 || {
    echo "Set GODOT_BIN to a Godot executable with matching Web export templates." >&2
    exit 1
}
echo "Export runtime: $("$GODOT_BIN" --version)"
[[ "${1:-}" != --check ]] || exit 0
export GODOT_BIN

# Export an isolated copy so the editor's project and import cache stay intact.
python3 - <<'PY'
from pathlib import Path
import re
import shutil
import hashlib
import json
import subprocess
import os
from datetime import datetime, timezone

build = Path('build')
build.mkdir(exist_ok=True)
(build / '.gdignore').touch()
for name in ('staging', 'web'):
    destination = build / name
    if destination.exists():
        shutil.rmtree(destination)
shutil.copytree('ldjam_60', build / 'staging', ignore=shutil.ignore_patterns(
    '.godot', '.git', '.DS_Store', 'addons', 'tests', 'export_presets.cfg',
    'export_credentials.cfg'))
# LiteTerrain's map script is a runtime dependency of archipelago_terrain.gd.
# Keep it while omitting the editor automation plugin from the distributable.
shutil.copytree('ldjam_60/addons/lite_terrain', build / 'staging/addons/lite_terrain',
                ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
(build / 'web').mkdir()
project = build / 'staging/project.godot'
source = project.read_text()
source = re.sub(r'^_mcp_game_helper=.*\n', '', source, flags=re.M)
source = re.sub(r'^enabled=PackedStringArray\(.*\)$',
                'enabled=PackedStringArray()', source, flags=re.M)
project.write_text(source)
digest = hashlib.sha256()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
engine_version = subprocess.check_output([os.environ['GODOT_BIN'], '--version'], text=True).strip()
# Provenance and export tooling also affect the pack, even on docs-only commits.
digest.update(head.encode() + b'\0' + engine_version.encode() + b'\0')
digest.update(Path('build_web.sh').read_bytes())
for path in sorted((build / 'staging').rglob('*')):
    if path.is_file():
        digest.update(str(path.relative_to(build / 'staging')).encode() + b'\0')
        digest.update(path.read_bytes())
info = {
    'git_sha': head,
    'godot_version': engine_version,
    'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
    'source_sha256': digest.hexdigest(),
    'commit_utc': datetime.fromisoformat(subprocess.check_output(['git', 'show', '-s', '--format=%cI', 'HEAD'], text=True).strip()).astimezone(timezone.utc).isoformat(),
    'configuration': 'single-thread Web / Compatibility / 960x540 viewport / 1280x720 max backing',
}
runtime_name = 'blackwater-runtime-' + info['source_sha256'][:12] + '.js'
info['runtime_script'] = runtime_name
(build / 'web/build.json').write_text(json.dumps(info, indent=2, sort_keys=True) + '\n')
(build / 'staging/game/build_info.json').write_text(json.dumps(info, sort_keys=True))
(build / 'web' / runtime_name).write_bytes(Path('ldjam_60/game/web_runtime.js').read_bytes())
(build / 'staging/export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="game/build_info.json"
exclude_filter="addons/godot_ai/*,tests/*"
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=0
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
html/head_include="<script src='RUNTIME_SCRIPT'></script>"
'''.replace('RUNTIME_SCRIPT', runtime_name))
PY

run_export_step() {
    local log="$1"
    local diagnostics
    shift
    if ! "$GODOT_BIN" --headless --path build/staging "$@" > "$log" 2>&1; then
        cat "$log" >&2
        return 1
    fi
    # Godot may report script/export errors while returning a success status.
    if diagnostics=$(LC_ALL=C grep -E 'ERROR:|SCRIPT ERROR:|Parse Error:' "$log"); then
        printf '%s\nSee %s\n' "$diagnostics" "$log" >&2
        return 1
    fi
}
run_export_step build/import.log --editor --quit
# Content-specific engine/pack filenames prevent stale itch caches mixing builds.
BUILD_ID="$(python3 -c 'import json; print(json.load(open("build/web/build.json"))["source_sha256"][:12])')"
run_export_step build/export.log --export-release Web "../web/blackwater-${BUILD_ID}.html"
mv "build/web/blackwater-${BUILD_ID}.html" build/web/index.html

python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib
import json

web = Path('build/web')
info = json.loads((web / 'build.json').read_text())
# The engine's adaptive policy multiplies CSS size by DPR, including fullscreen.
# Let the shipped runtime own a bounded presentation buffer instead. Set a safe
# initial buffer before WebGL context creation; CSS still fills the iframe.
html = web / 'index.html'
source = html.read_text()
if source.count('<canvas id="canvas">') != 1 or '</style>' not in source:
    raise SystemExit('Web template changed: verify bounded canvas sizing before packaging.')
source = source.replace('<canvas id="canvas">', '<canvas id="canvas" width="1280" height="720">')
source = source.replace('</style>', '''#canvas { width: 100vw; height: 100vh; }
</style>''', 1)
html.write_text(source)
prefix = 'blackwater-' + info['source_sha256'][:12]
for name in ('index.html', prefix + '.js', prefix + '.wasm', prefix + '.pck', info['runtime_script']):
    output = web / name
    if not output.is_file() or output.stat().st_size == 0:
        raise SystemExit(f'Web export incomplete: {output}. See build/export.log.')
checksums = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(web.iterdir()) if p.is_file()}
(web / 'checksums.json').write_text(json.dumps(checksums, indent=2, sort_keys=True) + '\n')
versioned = Path('build') / ('blackwater-web-' + info['git_sha'][:12] + '-' + info['source_sha256'][:12] + '.zip')
with ZipFile(versioned, 'w', ZIP_DEFLATED, compresslevel=9) as archive:
    for output in sorted(web.iterdir()):
        if output.is_file():
            entry = ZipInfo(output.name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, output.read_bytes())
import shutil
shutil.copyfile(versioned, 'build/blackwater-web.zip')
print('Ready: ' + str(versioned))
PY
