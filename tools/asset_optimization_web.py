"""Prepare an isolated Web benchmark with matching engine/templates; no upload."""
from pathlib import Path
import shutil
import re
import subprocess
import argparse
p=argparse.ArgumentParser()
p.add_argument('--godot', required=True)
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
build=root/'build/asset_optimization'
source=build/'source'
source.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'ldjam_60',source,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot','addons','tests','export_presets.cfg','export_credentials.cfg'))
shutil.copytree(root/'ldjam_60/addons/lite_terrain',source/'addons/lite_terrain',dirs_exist_ok=True)
(source/'tests').mkdir(exist_ok=True)
for name in ['asset_optimization.gd','asset_optimization.tscn']:
 shutil.copy2(root/'ldjam_60/tests'/name,source/'tests'/name)
project=source/'project.godot'
s=project.read_text()
s=re.sub(r'^_mcp_game_helper=.*\n','',s,flags=re.M)
s=re.sub(r'^enabled=PackedStringArray\(.*\)$','enabled=PackedStringArray()',s,flags=re.M)
s=s.replace('run/main_scene="res://game/crossing.tscn"','run/main_scene="res://tests/asset_optimization.tscn"')
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
(build/'web').mkdir(exist_ok=True)
for name,args in [('import',['--editor','--quit']),('export',['--export-release','Web','../web/index.html'])]:
 with (build/(name+'.log')).open('w') as f:
  subprocess.run([a.godot,'--headless','--path',str(source),*args],stdout=f,stderr=subprocess.STDOUT,check=True)
 print(name,'finished; inspect log for diagnostics')
