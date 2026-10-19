"""Serve the production Web export and a sandboxed itch-style iframe locally.

No receiver or telemetry endpoint. Open /embed.html. Pointer lock is deliberately
denied in the frame; keyboard steering must still work. The text-only export
fallback can be checked at /embed-no-download.html.
"""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('build/web'))
    parser.add_argument('--port', type=int, default=8782)
    args = parser.parse_args()
    root = args.root.resolve()

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(root), **kw)

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()

        def do_GET(self):
            if self.path not in ('/embed.html', '/embed-no-download.html', '/measure.html'):
                return super().do_GET()
            downloads = '' if self.path == '/embed-no-download.html' else ' allow-downloads'
            meter = '''<button id="meter">Measure 60 seconds (starts after 5 seconds)</button>
<label>Run label <input id="label" value="recorder-off-960"></label>
<p id="meter-status">External parent-frame timing; the production recorder can remain off.</p>
<textarea id="measurement" aria-label="Frame measurement JSON" style="width:90%;height:120px" readonly></textarea>
<script>
document.getElementById('meter').onclick = () => {
 const rows = [], begin = performance.now()+5000; let previous=0;
 const label=document.getElementById('label').value;
 const status=document.getElementById('meter-status'); status.textContent='Starting in 5 seconds: click the game and Resume if paused.';
 function tick(t) {
  if(t>=begin) { if(previous) rows.push([t,t-previous]); previous=t; status.textContent='Recording '+((t-begin)/1000).toFixed(0)+' / 60 seconds'; }
  if(t<begin+60000) return requestAnimationFrame(tick);
  const v=rows.map(r=>r[1]).sort((a,b)=>a-b), q=p=>v[Math.ceil((v.length-1)*p)];
  document.getElementById('measurement').value=JSON.stringify({label,clock:'parent requestAnimationFrame',device_pixel_ratio:devicePixelRatio,
   user_agent:navigator.userAgent,frames:rows,summary:{frames:v.length,median_ms:q(.5),p95_ms:q(.95),p99_ms:q(.99),max_ms:v.at(-1),mean_ms:v.reduce((a,b)=>a+b,0)/v.length}});
  status.textContent='Complete. Copy the measurement JSON.';
 }
 requestAnimationFrame(tick);
};
</script>''' if self.path == '/measure.html' else ''
            html = f'''<!doctype html><html lang="en"><meta charset="utf-8">
<title>Blackwater embedded release review</title>
<style>body{{background:#192735;color:#eee;font:16px sans-serif;padding:20px}}
iframe{{display:block;width:min(960px,95vw);height:min(540px,53.4375vw);border:1px solid #d6ac68;margin:16px 0}}
button{{padding:10px;margin:8px}}a{{color:#d6ac68}}</style>
<h1>Blackwater · local release review</h1>
<p>Sandbox denies pointer lock. Focus loss must pause. Keyboard controls must work.</p>
<button id="outside">Outside game</button>
<button onclick="document.getElementById('game').requestFullscreen()">Fullscreen game</button>
<a href="/index.html">Standalone</a>
<iframe id="game" title="Blackwater game" src="/index.html" allow="autoplay; fullscreen"
allowfullscreen sandbox="allow-scripts allow-same-origin{downloads}"></iframe>
<p>F8 or Settings → Diagnostics. Enable recording, Close, then Resume.
Use Export Diagnostics → Download JSON, or select/copy the JSON text.</p>{meter}</html>'''
            payload = html.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    print(f'Production export: http://127.0.0.1:{args.port}/index.html', flush=True)
    print(f'Embedded review: http://127.0.0.1:{args.port}/embed.html', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
