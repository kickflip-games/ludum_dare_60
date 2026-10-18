"""Serve isolated combat snapshots and collect local WebGL JSON (no publication).

Prepare each label with tools/runtime_performance.py --fixture combat_events
--output-root build/combat_events --web. Then run this server and open
http://127.0.0.1:8769/before/web/index.html (or after). Click the canvas once to
start and enable audio. Optional query: probe=no_arrival|no_audio|no_vfx|no_flame|no_ball,
full-seconds=60, cases=first_volley, label=before-repeat. Keep the tab visible; run one renderer at a
time. Native: ENGINE --path build/combat_events/before/source --resolution
1280x720 --disable-render-loop -- --manual-render --label=before --output=/tmp/blackwater-combat.
"""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('build/combat_events'))
    parser.add_argument('--port', type=int, default=8769)
    args = parser.parse_args()
    root = args.root.resolve()
    (root / 'results').mkdir(parents=True, exist_ok=True)

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(root), **kw)

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()

        def do_POST(self):
            if self.path != '/result':
                self.send_error(404)
                return
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size < 20_000_000:
                self.send_error(413)
                return
            try:
                data = json.loads(self.rfile.read(size))
                name = f"web-{data['label']}-{data['probe']}.json"
                if not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
                    raise ValueError('Invalid result label')
            except (ValueError, KeyError):
                self.send_error(400)
                return
            destination = root / 'results' / name
            if destination.exists():
                self.send_error(409, 'Result exists; use a new label')
                return
            destination.write_text(json.dumps(data, indent=2))
            self.send_response(200)
            self.end_headers()

    print(f'Serving {root} at http://127.0.0.1:{args.port}')
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
