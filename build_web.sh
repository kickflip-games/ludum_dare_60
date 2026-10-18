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

# Export an isolated copy so the editor's project and import cache stay intact.
python3 - <<'PY'
from pathlib import Path
import re
import shutil

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
(build / 'staging/export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="addons/godot_ai/*,tests/*"
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
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
run_export_step build/export.log --export-release Web ../web/index.html

python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

web = Path('build/web')
for name in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
    output = web / name
    if not output.is_file() or output.stat().st_size == 0:
        raise SystemExit(f'Web export incomplete: {output}. See build/export.log.')
with ZipFile('build/blackwater-web.zip', 'w', ZIP_DEFLATED) as archive:
    for output in sorted(web.iterdir()):
        if output.is_file():
            archive.write(output, output.name)
print('Ready: build/blackwater-web.zip')
PY
