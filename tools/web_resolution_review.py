"""Serve production exports in a 1680x911 sandboxed iframe; save local evidence.

Example: python3 tools/web_resolution_review.py --root build/resolution/before/web
Use Chrome at 100% zoom on a DPR 2 display. No fixed simulation delta or pilot.
The child-frame rAF meter works with the game's recorder both off and on.
"""
import argparse
import json
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


METER = r'''<script>
window.addEventListener('message', e => {
 if(e.source!==parent || e.data?.kind!=='measure') return;
 const rows=[], samples=[], begin=performance.now()+5000, end=begin+e.data.seconds*1000;
 let previous=0, sampled=0;
 function tick(t) {
  if(t>=begin) {
   if(previous) rows.push([t,t-previous]); previous=t;
   if(t-sampled>1000) { sampled=t; samples.push({t_ms:t,environment:JSON.parse(BlackwaterRuntime.snapshot())}); }
  }
  if(t<end) return requestAnimationFrame(tick);
  parent.postMessage({kind:'measurement',label:e.data.label,rows,samples,
   runtime:JSON.parse(BlackwaterRuntime.report())},'*');
 }
 requestAnimationFrame(tick);
});
</script>'''

PAGE = r'''<!doctype html><meta charset="utf-8"><title>Blackwater resolution review</title>
<style>body{margin:0;background:#192735;color:#eee;font:16px sans-serif}iframe{display:block;width:1680px;height:911px;border:0}button,input{margin:5px;padding:6px}iframe:fullscreen{width:100vw;height:100vh}</style>
<label>Run label <input id="label" value="before-960-off-combat"></label>
<label>Seconds <input id="seconds" type="number" value="30" min="5" max="180"></label>
<button id="measure">Measure</button><button id="outside">Outside game</button>
<button id="fullscreen">Fullscreen</button><button id="resize">Resize iframe</button>
<button id="save">Save exported diagnostics</button><span id="status">Ready</span>
<iframe id="game" title="Blackwater" src="/index.html" allow="autoplay; fullscreen" allowfullscreen sandbox="allow-scripts allow-same-origin allow-downloads"></iframe>
<script>
const game=document.querySelector('#game'),status=document.querySelector('#status');
document.querySelector('#measure').onclick=()=>{
 status.textContent='Starting in 5 seconds; focus game and Resume. Recording child rAF.';
 game.contentWindow.postMessage({kind:'measure',label:document.querySelector('#label').value,seconds:+document.querySelector('#seconds').value},'*');
};
async function save(label,data) {
 const r=await fetch('/result/'+encodeURIComponent(label),{method:'POST',body:JSON.stringify(data)});
 status.textContent=r.ok?'Saved '+label:'Save failed '+r.status;
}
window.addEventListener('message',e=>{if(e.source===game.contentWindow&&e.data.kind==='measurement')save(e.data.label,e.data);});
document.querySelector('#save').onclick=()=>{
 const text=game.contentDocument.querySelector('#blackwater-export textarea');
 if(text)save(document.querySelector('#label').value+'-diagnostics',JSON.parse(text.value));
 else status.textContent='Open F8 → Export Diagnostics first';
};
document.querySelector('#fullscreen').onclick=()=>game.requestFullscreen().catch(e=>status.textContent=e.message);
document.querySelector('#resize').onclick=()=>{game.style.width=game.clientWidth===1680?'1120px':'1680px';game.style.height=game.clientHeight===911?'630px':'911px';};
</script>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('build/web'))
    parser.add_argument('--output', type=Path, default=Path('build/resolution/results'))
    parser.add_argument('--port', type=int, default=8783)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(args.root.resolve()), **kw)

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()

        def do_GET(self):
            if self.path == '/review.html':
                payload = PAGE.encode()
            elif self.path == '/index.html':
                payload = (args.root / 'index.html').read_text().replace('</head>', METER + '</head>').encode()
            else:
                return super().do_GET()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_POST(self):
            name = self.path.removeprefix('/result/')
            size = int(self.headers.get('Content-Length', '0'))
            if not self.path.startswith('/result/') or not re.fullmatch(r'[A-Za-z0-9_-]+', name) or not 0 < size < 20_000_000:
                return self.send_error(400)
            try:
                data = json.loads(self.rfile.read(size))
                # Preserve earlier measurements when a label is reused.
                with (args.output / (name + '.json')).open('x') as f:
                    json.dump(data, f)
            except (ValueError, FileExistsError):
                return self.send_error(409)
            self.send_response(200)
            self.end_headers()

    print(f'Local review: http://127.0.0.1:{args.port}/review.html', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
