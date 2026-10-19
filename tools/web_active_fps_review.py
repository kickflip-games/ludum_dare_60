"""Serve the real production export in a sandboxed 960x540 iframe. Local only."""
import argparse
import json
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote

PAGE = b'''<!doctype html><meta charset="utf-8"><title>Blackwater active FPS investigation</title>
<style>body{background:#192735;color:#eee;font:16px sans-serif}iframe{width:960px;height:540px;border:0}button{padding:8px}</style>
<p>Production scene at 960x540. Click Run FPS A/B inside the frame; keep it focused. One component changes per case.</p>
<button onclick="document.querySelector('iframe').requestFullscreen()">Fullscreen</button>
<span id="status">Waiting for result</span>
<iframe title="Blackwater" src="/index.html?perf_ab=1" allow="autoplay; fullscreen" allowfullscreen sandbox="allow-scripts allow-same-origin allow-downloads"></iframe>
<script>let saved=false;setInterval(async()=>{
 const frame=document.querySelector('iframe'),result=frame.contentDocument?.querySelector('#blackwater-ab-result');
 if(!result||saved)return;saved=true;
 const r=await fetch('/result',{method:'POST',body:result.value});
 document.querySelector('#status').textContent=r.ok?'Saved A/B report locally':'Save failed';
},1000);</script>'''

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--root',type=Path,default=Path('build/web'))
 p.add_argument('--output',type=Path,default=Path('build/active_fps/results.json'))
 p.add_argument('--port',type=int,default=8784)
 p.add_argument('--cases',default='',help='Optional comma-separated subset of the built-in cases')
 a=p.parse_args();a.output.parent.mkdir(parents=True,exist_ok=True)
 class Handler(SimpleHTTPRequestHandler):
  def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(a.root.resolve()),**kwargs)
  def end_headers(self):
   self.send_header('Cache-Control','no-store');super().end_headers()
  def do_GET(self):
   if self.path=='/review.html':
    page=PAGE.replace(b'?perf_ab=1', ('?perf_ab=1&perf_cases='+quote(a.cases)).encode())
    self.send_response(200);self.send_header('Content-Type','text/html');self.end_headers();self.wfile.write(page)
   else:super().do_GET()
  def do_POST(self):
   size=int(self.headers.get('Content-Length','0'))
   if self.path!='/result' or not 0<size<20000000:return self.send_error(400)
   data=json.loads(self.rfile.read(size))
   with a.output.open('x') as f:json.dump(data,f)
   self.send_response(200);self.end_headers()
 print(f'http://127.0.0.1:{a.port}/review.html',flush=True)
 ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()

if __name__=='__main__':main()
