"""Freeze the current working tree for native / Web comparison; never publish."""
import argparse
from pathlib import Path
import shutil
import re
import subprocess
p=argparse.ArgumentParser()
p.add_argument('--label', choices=['before','after'],required=True)
p.add_argument('--godot',required=True)
p.add_argument('--web',action='store_true')
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
build=root/'build/runtime_performance'/a.label
source=build/'source'
if source.exists(): raise SystemExit(f'Refusing to overwrite snapshot {source}')
shutil.copytree(root/'ldjam_60',source,ignore=shutil.ignore_patterns('.godot','addons','export_presets.cfg','export_credentials.cfg'))
shutil.copytree(root/'ldjam_60/addons/lite_terrain',source/'addons/lite_terrain')
project=source/'project.godot'
s=project.read_text()
s=re.sub(r'^_mcp_game_helper=.*\n','',s,flags=re.M)
s=re.sub(r'^enabled=PackedStringArray\(.*\)$','enabled=PackedStringArray()',s,flags=re.M)
s=s.replace('run/main_scene="res://game/crossing.tscn"','run/main_scene="res://tests/runtime_performance.tscn"')
project.write_text(s)
(source/'export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
script_export_mode=2
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
''')
steps=[('import',['--editor','--quit'])]
if a.web:
 (build/'web').mkdir(exist_ok=True)
 steps.append(('export',['--export-release','Web','../web/index.html']))
for name,args in steps:
 with (build/(name+'.log')).open('w') as stream:
  subprocess.run([a.godot,'--headless','--path',str(source),*args],stdout=stream,stderr=subprocess.STDOUT,check=True)
 text=(build/(name+'.log')).read_text()
 errors=[line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line]
 if errors:raise SystemExit('\n'.join(errors))
print(source)
