"""Isolated baseline/final Web review, with optional local result collection.

python tools/turbulence_web_review.py --prepare --godot PATH --templates DIR
python tools/turbulence_web_review.py --serve

Templates must match the engine. No installs, source swaps or recursive deletes.
Open the printed URL in one browser tab; 24 alternating 40-second runs take about
16 minutes. Keep other GPU workloads/recording closed during timed samples.
"""
from argparse import ArgumentParser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import re
import shutil
import subprocess
import zipfile

REPO = Path(__file__).resolve().parents[1]


def run_engine(engine, source, arguments, log):
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run([engine, '--headless', '--path', str(source), *arguments],
                                stdout=stream, stderr=subprocess.STDOUT)
    diagnostics = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or re.search(r'ERROR:|SCRIPT ERROR:|Parse Error:', diagnostics):
        raise RuntimeError(f'Engine step failed; inspect {log}')


def prepare(args, build):
    if not args.godot or not args.templates:
        raise ValueError('--prepare requires --godot and --templates')
    template_dir = Path(args.templates).resolve()
    for mode in ['debug', 'release']:
        if not (template_dir / f'web_nothreads_{mode}.zip').is_file():
            raise ValueError(f'Missing matching single-thread Web template in {template_dir}')
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    template_version = template_dir / 'version.txt'
    if template_version.exists() and not version.startswith(template_version.read_text().strip()):
        raise ValueError('Engine and template versions differ')
    baseline = subprocess.check_output(['git', 'rev-parse', args.baseline], cwd=REPO, text=True).strip()
    build.mkdir(parents=True, exist_ok=True)
    (REPO / 'build').mkdir(exist_ok=True)
    (REPO / 'build' / '.gdignore').touch()
    archive = build / 'baseline.zip'
    unpacked = build / 'baseline-unpacked'
    if unpacked.exists():
        raise FileExistsError(f'Use a new --output directory; preserving {unpacked}')
    subprocess.run(['git', 'archive', baseline, 'ldjam_60', '-o', str(archive)], cwd=REPO, check=True)
    with zipfile.ZipFile(archive) as source_zip:
        source_zip.extractall(unpacked)
    for variant in ['baseline', 'final', 'release']:
        source = build / f'{variant}-source'
        original = unpacked / 'ldjam_60' if variant == 'baseline' else REPO / 'ldjam_60'
        shutil.copytree(original, source, ignore=shutil.ignore_patterns(
            '.godot', 'addons', 'tests', 'export_presets.cfg', 'export_credentials.cfg'))
        # Terrain needs its runtime addon; the editor automation addon is omitted.
        shutil.copytree(original / 'addons' / 'lite_terrain', source / 'addons' / 'lite_terrain')
        development = variant != 'release'
        if development:
            (source / 'tests').mkdir()
            for name in ['turbulence_browser.gd', 'turbulence_browser.tscn']:
                shutil.copy2(REPO / 'ldjam_60' / 'tests' / name, source / 'tests' / name)
        project = source / 'project.godot'
        text = project.read_text()
        text = re.sub(r'^_mcp_game_helper=.*\n', '', text, flags=re.M)
        text = re.sub(r'^enabled=PackedStringArray\(.*\)$', 'enabled=PackedStringArray()', text, flags=re.M)
        if development:
            text = text.replace('run/main_scene="res://game/crossing.tscn"',
                                'run/main_scene="res://tests/turbulence_browser.tscn"')
        project.write_text(text)
        (source / 'export_presets.cfg').write_text(f'''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="addons/godot_ai/*{'' if development else ',tests/*'}"
script_export_mode=2
[preset.0.options]
custom_template/debug="{(template_dir / 'web_nothreads_debug.zip').as_posix()}"
custom_template/release="{(template_dir / 'web_nothreads_release.zip').as_posix()}"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=0
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
        destination = build / variant
        destination.mkdir()
        run_engine(args.godot, source, ['--editor', '--import', '--quit'], build / f'{variant}-import.log')
        run_engine(args.godot, source, ['--export-release', 'Web', str(destination / 'index.html')], build / f'{variant}-export.log')
        for name in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
            if not (destination / name).is_file() or (destination / name).stat().st_size == 0:
                raise RuntimeError(f'Incomplete export: {destination / name}')
        html = destination / 'index.html'
        text = html.read_text().replace('<canvas id="canvas"', '<canvas width="1280" height="720" id="canvas"')
        if development:
            text = text.replace('</body>', '<pre id="bench-status" style="position:fixed;right:8px;top:0;color:white;background:#14232bd9;max-width:420px;font:11px monospace;white-space:pre-wrap;pointer-events:none">Loading...</pre></body>')
        html.write_text(text)
    with zipfile.ZipFile(build / 'latitude-lines-web.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted((build / 'release').iterdir()):
            if path.is_file(): bundle.write(path, path.name)
    (build / 'metadata.json').write_text(json.dumps({'engine': version, 'baseline': baseline,
        'final': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip(),
        'note': 'Final is copied from the working tree. Timings include the complete rendered frame.'}, indent=2))


def serve(build, port):
    class Handler(SimpleHTTPRequestHandler):
        def do_POST(self):
            if self.path != '/result':
                self.send_error(404)
                return
            count = int(self.headers.get('Content-Length', '0'))
            if count > 100_000:
                self.send_error(413)
                return
            data = json.loads(self.rfile.read(count))
            with (build / 'browser-results.jsonl').open('a', encoding='utf-8') as output:
                output.write(json.dumps(data) + '\n')
            print(json.dumps(data), flush=True)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')

        def log_message(self, *_args):
            pass

    url = f'http://127.0.0.1:{port}/baseline/index.html?version=baseline&run=0&cohort=review'
    print(f'Open {url}\nResults: {build / "browser-results.jsonl"}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), partial(Handler, directory=str(build))).serve_forever()


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--serve', action='store_true')
    parser.add_argument('--godot')
    parser.add_argument('--templates')
    parser.add_argument('--baseline', default='96e14a3')
    parser.add_argument('--output', default=str(REPO / 'build' / 'turbulence-web-review'))
    parser.add_argument('--port', type=int, default=8766)
    args = parser.parse_args()
    build = Path(args.output).resolve()
    if args.prepare:
        prepare(args, build)
    if args.serve:
        serve(build, args.port)
    if not args.prepare and not args.serve:
        parser.print_help()


if __name__ == '__main__':
    main()
