from pathlib import Path
import re, random
p=Path(__file__).parent
random.seed(19)
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900"><defs><radialGradient id="a" cx="-12%" cy="44%" r="100%"><stop stop-color="#76602d"/><stop offset=".45" stop-color="#292714"/><stop offset="1" stop-color="#080b0d"/></radialGradient><linearGradient id="b"><stop stop-color="#f5d98f" stop-opacity=".65"/><stop offset=".16" stop-color="#aa8f47" stop-opacity=".08"/><stop offset="1" stop-opacity="0"/></linearGradient></defs><rect width="1600" height="900" fill="url(#a)"/><rect width="800" height="900" fill="url(#b)"/>']
for _ in range(85):
 x,y=random.randrange(780),random.randrange(900)
 r=random.choice([1,2,3,7,14,24])
 parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#ddc477" opacity="{random.uniform(.015,.10):.3f}"/>')
parts.append('</svg>')
(p/'hero-atmosphere.svg').write_text(''.join(parts),encoding='utf-8')
f=p/'hub.tscn';s=f.read_text(encoding='utf-8')
s=s.replace('load_steps=3','load_steps=5')
s=s.replace('[node name="Root"', '[ext_resource type="Texture2D" path="res://ui/rebuild/iteration-003/hero-atmosphere.svg" id="3_hero"]\n[ext_resource type="Script" path="res://ui/rebuild/shared/course_row.gd" id="4_row"]\n\n[node name="Root"',1)
def edit(name, changes, parent='Catalog'):
 global s
 pat=rf'(\[node name="{name}"[^\n]*parent="{parent}"\]\n)(.*?)(?=\n\[|\Z)'
 m=re.search(pat,s,re.S)
 if not m: raise ValueError(name)
 body=m[2]
 for key,val in changes.items():
  line=f'{key} = {val}'
  body=re.sub(rf'^{re.escape(key)} = .*$',lambda _:line,body,flags=re.M) if re.search(rf'^{re.escape(key)} =',body,re.M) else body+'\n'+line+'\n'
 s=s[:m.start(2)]+body+s[m.end(2):]
edit('BackgroundArt',{'texture':'ExtResource("3_hero")','offset_top':'0.0','offset_right':'1600.0','offset_bottom':'900.0'})
edit('HeroKicker',{'offset_top':'248.0','offset_bottom':'276.0'})
edit('HeroTitle',{'offset_top':'351.0','offset_bottom':'450.0','theme_override_font_sizes/font_size':'43','text':'"准星归位，\\n从这一轮开始。"'})
edit('HeroCopy',{'offset_top':'474.0','offset_bottom':'538.0','text':'"找一个想练的项目，按自己的节奏开始。\\n也可以先和麦小鼠聊聊今天的状态。"'})
edit('Difficulty',{'offset_top':'562.0','offset_bottom':'606.0'})
edit('Invincible',{'offset_top':'564.0','offset_bottom':'604.0'})
edit('Tools',{'offset_left':'1000.0','offset_right':'1264.0','offset_top':'850.0','offset_bottom':'895.0'})
edit('Training',{'offset_left':'1276.0','offset_right':'1548.0','offset_top':'850.0','offset_bottom':'895.0','theme_type_variation':'&"PrimaryButton"'})
for i in range(12): edit(f'Course{i}',{'script':'ExtResource("4_row")'})
edit('FilterRow',{'text':'"训练目录   ·   12 个基础项目"'})
edit('RecentTab',{'text':'"基础训练"'})
# Draw the task border above the background, below its content.
m=re.search(r'\[node name="TaskFrame".*?(?=\n\[|\Z)',s,re.S); block=m[0].replace('show_behind_parent = true\n','');s=s[:m.start()]+s[m.end():]
s=s.replace('[node name="TasksHeading"',block+'\n\n[node name="TasksHeading"',1)
s=s.replace('text = "训练库      学习      记录      设置"','text = "嘉豪训练器    /    训练与陪伴"')
f.write_text(s,encoding='utf-8')
