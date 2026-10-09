# Orthographic design drawings for the segmented cover set (front / side / top, metres).
import os
HERE = os.path.dirname(os.path.abspath(__file__))
S = 120.0  # px per metre
GR, MET, BODY_W, BODY_B, BODY_D, ORA = "#2B2F33", "#A9AEB2", "#C4D0D8", "#61798F", "#3B4652", "#B4521E"

def rect(x, y, w, h, fill, stroke="#111", sw=1.2):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def text(x, y, s, size=15, anchor="middle", fill="#111"):
    return f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}" fill="{fill}" font-family="Noto Sans SC, sans-serif">{s}</text>'

def dim_h(x0, x1, y, label):
    return (f'<line x1="{x0:.1f}" y1="{y:.1f}" x2="{x1:.1f}" y2="{y:.1f}" stroke="#555" marker-start="url(#a)" marker-end="url(#a)"/>'
            + text((x0 + x1) / 2, y - 6, label, 13))

def dim_v(x, y0, y1, label):
    return (f'<line x1="{x:.1f}" y1="{y0:.1f}" x2="{x:.1f}" y2="{y1:.1f}" stroke="#555" marker-start="url(#a)" marker-end="url(#a)"/>'
            + text(x - 8, (y0 + y1) / 2, label, 13, "end"))

def elevation(ox, gy, W, H, body, plinth, band, cap, inset=0.03, guard=0.10):
    """Front elevation: ground line at gy, centred at ox (px)."""
    out = []
    L = ox - W / 2 * S
    out.append(rect(L + inset * S, gy - (H - cap) * S, (W - 2 * inset) * S, (H - cap - plinth) * S, body))
    out.append(rect(L, gy - plinth * S, W * S, plinth * S, GR))
    out.append(rect(L, gy - band[1] * S, W * S, (band[1] - band[0]) * S, GR))
    out.append(rect(L, gy - H * S, W * S, cap * S, GR))
    for gx in (L, L + (W - guard) * S):
        out.append(rect(gx, gy - (H - cap) * S, guard * S, (H - cap - plinth) * S, MET))
    return out

def step_elevation(ox, gy, W, H):
    L = ox - W / 2 * S
    return [rect(L, gy - (H - 0.047) * S, W * S, (H - 0.047) * S, BODY_D),
            rect(L + 0.02 * S, gy - H * S, (W - 0.04) * S, 0.047 * S, MET),
            rect(L, gy - (H - 0.047) * S, W * S, 0.05 * S, ORA)]

parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1000" viewBox="0 0 1800 1000">',
         '<defs><marker id="a" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,4 L8,0 L8,8 Z" fill="#555"/></marker></defs>',
         '<rect width="1800" height="1000" fill="#F4F5F6"/>',
         text(900, 42, "掩体分段射击 · 训练掩体套件 · 模块三视图（单位 m，外包络 = 现有碰撞盒）", 22)]
gy = 520
# --- SC_COVER_TALL
parts += [text(260, 110, "SC_COVER_TALL 玩家掩体 · 正视", 17)]
parts += elevation(260, gy, 2.608, 1.906, BODY_W, 0.10, (0.86, 0.96), 0.126)
parts += [dim_h(260 - 1.304 * S, 260 + 1.304 * S, gy + 40, "2.608"), dim_v(260 - 1.304 * S - 20, gy - 1.906 * S, gy, "1.906")]
parts += [text(640, 110, "侧视", 17)]
parts += elevation(640, gy, 2.149, 1.906, BODY_W, 0.10, (0.86, 0.96), 0.126)
parts += [dim_h(640 - 1.0745 * S, 640 + 1.0745 * S, gy + 40, "2.149")]
# --- SC_COVER_LOW
parts += [text(1010, 110, "SC_COVER_LOW 敌方矮墙 · 正视", 17)]
parts += elevation(1010, gy, 1.249, 1.254, BODY_B, 0.08, (0.58, 0.66), 0.084, inset=0.025, guard=0.08)
parts += [dim_h(1010 - 0.6245 * S, 1010 + 0.6245 * S, gy + 40, "1.249"), dim_v(1010 - 0.6245 * S - 20, gy - 1.254 * S, gy, "1.254")]
parts += [text(1250, 110, "侧视", 17)]
parts += elevation(1250, gy, 1.023, 1.254, BODY_B, 0.08, (0.58, 0.66), 0.084, inset=0.025, guard=0.08)
parts += [dim_h(1250 - 0.5115 * S, 1250 + 0.5115 * S, gy + 40, "1.023")]
# --- SC_STEP
parts += [text(1480, 110, "SC_STEP 跳射踏步 · 正视", 17)]
parts += step_elevation(1480, gy, 0.707, 0.607)
parts += [dim_h(1480 - 0.3535 * S, 1480 + 0.3535 * S, gy + 40, "0.707"), dim_v(1480 - 0.3535 * S - 20, gy - 0.607 * S, gy, "0.607")]
parts += [text(1660, 110, "侧视", 17)]
parts += step_elevation(1660, gy, 1.101, 0.607)
parts += [f'<line x1="60" y1="{gy}" x2="1760" y2="{gy}" stroke="#333" stroke-width="2"/>']
# --- plan views (top)
py = 760
parts += [text(60, py - 150, "俯视（下排）", 15, "start")]
parts += [rect(260 - 1.304 * S, py - 1.0745 * S, 2.608 * S, 2.149 * S, GR)]
for sx in (-1, 1):
    for sz in (-1, 1):
        parts += [rect(260 + sx * 1.304 * S - (0.10 * S if sx > 0 else 0), py + sz * 1.0745 * S - (0.10 * S if sz > 0 else 0), 0.10 * S, 0.10 * S, MET)]
parts += [rect(1010 - 0.6245 * S, py - 0.5115 * S, 1.249 * S, 1.023 * S, GR)]
parts += [rect(1480 - 0.3335 * S, py - 0.5305 * S, 0.667 * S, 1.061 * S, MET)]
for k in range(5):
    parts += [rect(1480 - 0.30 * S, py - 0.45 * S + k * 0.21 * S, 0.60 * S, 0.035 * S, GR, sw=0.5)]
parts += [rect(1480 - 0.3535 * S, py - 0.5505 * S, 0.707 * S, 0.05 * S, ORA, sw=0.5), rect(1480 - 0.3535 * S, py + 0.5005 * S, 0.707 * S, 0.05 * S, ORA, sw=0.5)]
# legend
lx, ly = 1180, 880
for i, (c, n) in enumerate(((BODY_W, "white_grid 主体"), (BODY_B, "blue_grid 主体"), (BODY_D, "dark_grid 主体"), (GR, "石墨 接缝/压顶"), (MET, "裸金属 护角/踏板"), (ORA, "暗橙 踏边"))):
    parts += [rect(lx + (i % 3) * 200, ly + (i // 3) * 34, 22, 22, c), text(lx + (i % 3) * 200 + 30, ly + (i // 3) * 34 + 17, n, 14, "start")]
parts += [text(60, 975, "护角=探头边的竖向高光线；所有可见面位于碰撞包络内（板面内收 0.4 cm）。", 14, "start")]
parts.append('</svg>')
with open(os.path.join(HERE, "01-模块三视图.svg"), "w", encoding="utf-8") as f:
    f.write("\n".join(parts))
print("ok")
