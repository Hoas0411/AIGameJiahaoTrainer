# Generates the kit's orthographic design drawings (SVG, metres). Run: python make_drawings.py
import os
OUT=os.path.dirname(os.path.abspath(__file__))
S=12.0  # px per metre
def svg(w,h,body,title):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"><rect width="{w}" height="{h}" fill="#eef2f4"/>
<style>text{{font:13px sans-serif;fill:#1d3240}} .t{{font:18px sans-serif;font-weight:bold}} .wall{{fill:#7c858b;stroke:#2b2f33;stroke-width:1}} .col{{fill:#5d666c;stroke:#2b2f33}} .floor{{fill:#d6dbde;stroke:#b9c0c4;stroke-width:.5}} .line{{stroke:#ffffff;stroke-width:1.6}} .bay{{fill:#9aa3a8;stroke:#2b2f33}} .plat{{fill:#a7aeb2;stroke:#2b2f33}} .edge{{fill:#b4521e}} .dim{{stroke:#c0392b;stroke-width:1;fill:none}} .dimt{{fill:#c0392b;font:12px sans-serif}} .seam{{fill:#2b2f33}} .bolt{{fill:#a9aeb2}}</style>
<text x="20" y="30" class="t">{title}</text>{body}</svg>'''
def X(x,ox): return ox+(x+17)*S
def Z(z,oz): return oz+(z+38)*S
# ---------------- 01 plan
ox,oz=60,60
b=[]
b.append(f'<rect x="{X(-16,ox)}" y="{Z(-36,oz)}" width="{32*S}" height="{48*S}" class="floor"/>')
for i in range(17):
    b.append(f'<path d="M {X(-16+2*i,ox)} {Z(-36,oz)} v {48*S}" stroke="#c7cdd0" stroke-width=".6"/>')
for j in range(25):
    b.append(f'<path d="M {X(-16,ox)} {Z(-36+2*j,oz)} h {32*S}" stroke="#c7cdd0" stroke-width=".6"/>')
# walls (outside thickness 0.4)
b.append(f'<rect x="{X(-16.4,ox)}" y="{Z(-36.4,oz)}" width="{32.8*S}" height="{0.4*S}" class="wall"/>')
b.append(f'<rect x="{X(-16.4,ox)}" y="{Z(12,oz)}" width="{32.8*S}" height="{0.4*S}" class="wall"/>')
b.append(f'<rect x="{X(-16.4,ox)}" y="{Z(-36.4,oz)}" width="{0.4*S}" height="{48.8*S}" class="wall"/>')
b.append(f'<rect x="{X(16,ox)}" y="{Z(-36.4,oz)}" width="{0.4*S}" height="{48.8*S}" class="wall"/>')
for k in range(13):
    z=-36+4*k
    for x in (-16,16):
        b.append(f'<rect x="{X(x-0.3+(0.1 if x<0 else -0.1),ox)}" y="{Z(z-0.3,oz)}" width="{0.6*S}" height="{0.6*S}" class="col"/>')
for k in range(9):
    x=-16+4*k
    for z in (-36,12):
        b.append(f'<rect x="{X(x-0.3,ox)}" y="{Z(z-0.3,oz)}" width="{0.6*S}" height="{0.6*S}" class="col"/>')
# lane / distance lines (white, non-emissive)
for z in (-32,-24,-16,-8,0,8):
    b.append(f'<path d="M {X(-15.5,ox)} {Z(z,oz)} h {31*S}" class="line"/>')
    b.append(f'<text x="{X(16.8,ox)}" y="{Z(z,oz)+4}">z={z}</text>')
# reaction bays
for x in (-10,-5,0,5,10):
    b.append(f'<rect x="{X(x-2,ox)}" y="{Z(-12.15,oz)}" width="{4*S}" height="{0.3*S}" class="bay"/>')
    b.append(f'<circle cx="{X(x,ox)}" cy="{Z(-10,oz)}" r="4" fill="#c0392b"/>')
b.append(f'<text x="{X(-16,ox)}" y="{Z(-13,oz)}">随机反应：挡板 4.0×3.0×0.3 m（z=−12），靶位 z=−10（红点）</text>')
# elevation platforms
for (x,z,h) in ((-10,-8,0.15),(-5,-16,2),(0,-24,4),(5,-12,1),(10,-20,3)):
    b.append(f'<rect x="{X(x-1.5,ox)}" y="{Z(z-1.5,oz)}" width="{3*S}" height="{3*S}" fill="none" stroke="#1f6f8b" stroke-dasharray="4 3" stroke-width="1.4"/>')
    b.append(f'<text x="{X(x-1.4,ox)}" y="{Z(z+0.4,oz)}" fill="#1f6f8b">平台 +{h:g} m</text>')
b.append(f'<circle cx="{X(0,ox)}" cy="{Z(10,oz)}" r="6" fill="#1d3240"/><text x="{X(0.6,ox)}" y="{Z(10.4,oz)}">出生点 (0,0,10) 朝 −Z</text>')
# dims
b.append(f'<path d="M {X(-16,ox)} {Z(14,oz)} h {32*S}" class="dim"/><text x="{X(-1,ox)}" y="{Z(15.3,oz)}" class="dimt">32.0 m（柱网 4.0 m ×8）</text>')
b.append(f'<path d="M {X(-18,ox)} {Z(-36,oz)} v {48*S}" class="dim"/><text x="{X(-18,ox)-5}" y="{Z(-12,oz)}" class="dimt" transform="rotate(-90 {X(-18,ox)-5} {Z(-12,oz)})">48.0 m（4.0 m ×12）</text>')
b.append(f'<text x="{X(-16,ox)}" y="{Z(17.5,oz)}">地板 2×2×0.12 m 平齐金属板；白色分道线 0.10 m 不发光；墙高 4.5 m，后墙 6.0 m；虚线框=高低差转移平台；实体条=随机反应挡板</text>')
W=int(X(20,ox)); H=int(Z(19,oz))
open(os.path.join(OUT,'01-平面.svg'),'w',encoding='utf-8').write(svg(W,H,''.join(b),'训练场装甲围合套件 · 01 正交平面（米制，上为 −Z）'))
# ---------------- 02 elevation + section
E=40.0
b=[]
ox,oy=60,420  # ground line y
def ex(x): return ox+(x+16.6)*E/2.5
def ey(y): return oy-y*E/2.5*1.0
s=E/2.5
# back wall elevation (6.0 m) 
b.append('<text x="60" y="70">A 后墙立面（z=−36，从玩家方向看）  比例 1:62.5</text>')
for k in range(8):
    x0=-16+4*k
    b.append(f'<rect x="{ex(x0)}" y="{ey(6.0)}" width="{4*s}" height="{6*s}" class="wall"/>')
    b.append(f'<rect x="{ex(x0)}" y="{ey(0.35)}" width="{4*s}" height="{0.35*s}" class="seam"/>')
    b.append(f'<rect x="{ex(x0)}" y="{ey(2.6)}" width="{4*s}" height="{0.2*s}" class="seam"/>')
    b.append(f'<rect x="{ex(x0)}" y="{ey(4.4)}" width="{4*s}" height="{0.2*s}" class="seam"/>')
    b.append(f'<rect x="{ex(x0)}" y="{ey(6.0)}" width="{4*s}" height="{0.25*s}" class="seam"/>')
    for yy in (2.5,4.5):
        for xx in (0.25,1.35,2.65,3.75):
            b.append(f'<circle cx="{ex(x0+xx)}" cy="{ey(yy)}" r="1.6" class="bolt"/>')
for k in range(9):
    x=-16+4*k
    b.append(f'<rect x="{ex(x-0.3)}" y="{ey(6.6)}" width="{0.6*s}" height="{6.6*s}" class="col"/>')
b.append(f'<path d="M {ex(-16.6)} {ey(0)} h {33.2*s}" stroke="#1d3240" stroke-width="2"/>')
for (y,t) in ((0.35,'踢脚 0.35'),(2.6,'检修槽 2.40–2.60'),(4.4,'检修槽 4.20–4.40'),(6.0,'压顶 6.00'),(6.6,'柱顶 6.60')):
    b.append(f'<path d="M {ex(16.7)} {ey(y)} h 18" class="dim"/><text x="{ex(16.7)+22}" y="{ey(y)+4}" class="dimt">+{t}</text>')
# side wall section
oy2=760
def sy(y): return oy2-y*s
b.append(f'<text x="60" y="{oy2-260}">B 侧墙剖面（4.5 m，墙内表面为基准，向外加厚）</text>')
x0=200
b.append(f'<rect x="{x0}" y="{sy(4.5)}" width="{0.4*s}" height="{4.5*s}" class="wall"/>')
b.append(f'<rect x="{x0-0.05*s}" y="{sy(0.35)}" width="{0.45*s}" height="{0.35*s}" class="seam"/>')
b.append(f'<rect x="{x0}" y="{sy(2.6)}" width="{0.06*s}" height="{0.2*s}" fill="#eef2f4"/>')
b.append(f'<rect x="{x0-0.05*s}" y="{sy(4.5)}" width="{0.5*s}" height="{0.12*s}" class="seam"/>')
b.append(f'<path d="M {x0-120} {sy(0)} h 400" stroke="#1d3240" stroke-width="2"/>')
b.append(f'<text x="{x0+0.6*s}" y="{sy(2.5)}">检修槽内凹 0.06 m</text><text x="{x0+0.6*s}" y="{sy(4.4)}">压顶外挑 0.05 m</text><text x="{x0+0.6*s}" y="{sy(0.2)}">踢脚外挑 0.05 m</text>')
b.append(f'<path d="M {x0} {sy(-0.4)} h {0.4*s}" class="dim"/><text x="{x0}" y="{sy(-0.9)}" class="dimt">墙厚 0.40</text>')
b.append(f'<path d="M {x0-30} {sy(0)} v {-4.5*s}" class="dim"/><text x="{x0-90}" y="{sy(2.2)}" class="dimt">4.50</text>')
open(os.path.join(OUT,'02-立面与剖面.svg'),'w',encoding='utf-8').write(svg(int(ex(16.7)+160),800,''.join(b),'训练场装甲围合套件 · 02 后墙立面与侧墙剖面'))
# ---------------- 03 module views
b=[]; s=36
def box(x,y,w,h,c='wall'): return f'<rect x="{x}" y="{y}" width="{w*s}" height="{h*s}" class="{c}"/>'
y0=420
# wall segment front
b.append('<text x="40" y="70">W4 墙段 4.0×4.5×0.4（正视）</text>')
b.append(box(40,y0-4.5*s,4,4.5)); b.append(box(40,y0-0.35*s,4,0.35,'seam')); b.append(box(40,y0-2.6*s,4,0.2,'seam')); b.append(box(40,y0-4.5*s,4,0.12,'seam'))
b.append(f'<rect x="{40+0.12*s}" y="{y0-2.3*s}" width="{3.76*s}" height="{1.85*s}" fill="none" stroke="#5a6267" stroke-width="2"/>')
b.append(f'<rect x="{40+0.12*s}" y="{y0-4.25*s}" width="{3.76*s}" height="{1.55*s}" fill="none" stroke="#5a6267" stroke-width="2"/>')
for xx in (0.25,1.35,2.65,3.75):
    for yy in (2.4,2.8):
        b.append(f'<circle cx="{40+xx*s}" cy="{y0-yy*s}" r="2.5" class="bolt"/>')
# column
b.append('<text x="250" y="70">C6 装甲柱 0.6×0.7×(5.1/6.6)</text>')
b.append(box(280,y0-5.1*s,0.6,5.1,'col')); b.append(box(280,y0-0.5*s,0.6,0.5,'seam'))
for yy in (1.0,2.0,3.0,4.0):
    b.append(f'<path d="M 280 {y0-yy*s} h {0.6*s}" stroke="#2b2f33"/>')
# floor
b.append('<text x="380" y="70">F2 地板 2.0×2.0×0.12（俯视）</text>')
b.append(box(390,100,2,2,'floor'))
for t in (0.5,1.0,1.5): b.append(f'<path d="M {390+t*s} 100 v {2*s}" stroke="#8c959a" stroke-width="1"/>')
for (xx,yy) in ((0.12,0.12),(1.88,0.12),(0.12,1.88),(1.88,1.88)): b.append(f'<circle cx="{390+xx*s}" cy="{100+yy*s}" r="3" fill="#2b2f33"/>')
# bay
b.append('<text x="40" y="480">TB 挡板 4.0×3.0×0.3（正视），钢框 0.12，底脚 0.6×0.5</text>')
yb=620
b.append(box(40,yb-3*s,4,3,'bay')); b.append(f'<rect x="{40}" y="{yb-3*s}" width="{4*s}" height="{3*s}" fill="none" stroke="#a9aeb2" stroke-width="{0.12*s}"/>')
b.append(box(40+0.3*s,yb-0.12*s,0.6,0.12,'seam')); b.append(box(40+3.1*s,yb-0.12*s,0.6,0.12,'seam'))
b.append(f'<path d="M {40} {yb-1.5*s} h {4*s}" stroke="#5a6267" stroke-width="2"/>')
# platforms
b.append('<text x="250" y="480">PF 平台 3.0×3.0×h（h=1/2/3/4），踏边 0.15 警示斜纹，背侧爬梯</text>')
for i,h in enumerate((1,2,3,4)):
    x=250+i*130*0.9
    b.append(box(x,yb-h*s*0.6/1,3*0.6,h*0.6,'plat'))
    b.append(f'<rect x="{x}" y="{yb-h*s*0.6}" width="{3*s*0.6}" height="{0.15*s*0.6}" class="edge"/>')
    b.append(f'<text x="{x}" y="{yb+16}">+{h} m</text>')
open(os.path.join(OUT,'03-模块四视图.svg'),'w',encoding='utf-8').write(svg(760,660,''.join(b),'训练场装甲围合套件 · 03 模块视图（按比例）'))
print('ok')
