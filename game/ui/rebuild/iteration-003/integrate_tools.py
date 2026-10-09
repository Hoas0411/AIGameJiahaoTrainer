from pathlib import Path
import re
p=Path(__file__).parent
(p/'workspace-gradient.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900"><defs><linearGradient id="g"><stop stop-color="#114553"/><stop offset="1" stop-color="#222530"/></linearGradient></defs><rect width="1600" height="900" fill="url(#g)"/></svg>',encoding='utf8')
f=p/'tools.tscn';s=f.read_text(encoding='utf8').replace('load_steps=3','load_steps=5')
s=s.replace('[node name="Root"','[ext_resource type="Texture2D" path="res://ui/rebuild/iteration-003/workspace-gradient.svg" id="3_bg"]\n[ext_resource type="Script" path="res://ui/rebuild/shared/course_row.gd" id="4_row"]\n\n[node name="Root"',1)
def edit(name,changes):
 global s
 m=re.search(rf'(\[node name="{name}"[^\n]*\]\n)(.*?)(?=\n\[|\Z)',s,re.S)
 if not m: raise ValueError(name)
 body=m[2]
 for k,v in changes.items():
  line=f'{k} = {v}'
  body=re.sub(rf'^{re.escape(k)} = .*$',lambda _:line,body,flags=re.M) if re.search(rf'^{re.escape(k)} =',body,re.M) else body+'\n'+line+'\n'
 s=s[:m.start(2)]+body+s[m.end(2):]
# Insert a true full-screen gradient before the sidebar and controls.
at=s.index('[node ',s.index('[node ')+1)
s=s[:at]+'''[node name="ReferenceAtmosphere" type="TextureRect" parent="."]
offset_right = 1600.0
offset_bottom = 900.0
texture = ExtResource("3_bg")
mouse_filter = 2

'''+s[at:]
edit('Background',{'visible':'false'})
edit('PlanTitle',{'offset_left':'1018.0','offset_top':'88.0','offset_right':'1550.0','offset_bottom':'125.0'})
edit('Cover',{'offset_top':'138.0','offset_bottom':'320.0','stretch_mode':'6'})
edit('PlanReason',{'offset_top':'138.0','offset_bottom':'324.0','theme_override_font_sizes/font_size':'17'})
for i in range(3):edit(f'Route{i}',{'script':'ExtResource("4_row")','flat':'false'})
s=s.replace('text = "训练库      学习      记录      设置"','text = "嘉豪训练器    /    训练路线"')
f.write_text(s,encoding='utf8')
