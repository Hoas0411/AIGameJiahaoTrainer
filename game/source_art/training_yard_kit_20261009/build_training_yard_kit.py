# Training Yard Kit — Blender build script (Blender 5.1, run headless or from the Text Editor).
# Produces the editable source scene  training_yard_kit.blend  next to this file,
# one GLB per module in  game/assets/models/training_yard_kit_20261009/,
# and design-stage renders (player view, orthographic overviews, bird's-eye) in renders/.
# Geometry is real, editable mesh data built with bmesh; nothing is generated in Godot.
# Units: metres. Blender Z-up; glTF export converts to Y-up (+Y_blender -> -Z_godot).
# Wall/bay modules: inner (player-facing) face on Blender y=0 facing -Y, depth toward +Y,
# origin at the bottom centre of the inner face.
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
EXPORT_DIR = os.path.join(GAME, "assets", "models", "training_yard_kit_20261009")
RENDER_DIR = os.path.join(HERE, "renders")
BLEND_PATH = os.path.join(HERE, "training_yard_kit.blend")
os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(RENDER_DIR, exist_ok=True)

# ------------------------------------------------------------------ scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

def collection(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent or scene.collection).children.link(c)
    return c

COL_MODULES = collection("Modules")
COL_REACTION = collection("Assembly_Reaction")
COL_ELEVATION = collection("Assembly_Elevation")
COL_CAM = collection("Cameras_Lights")

# ------------------------------------------------------------------ materials
def principled(name, color, rough, metal=0.0, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in b.inputs: b.inputs["Specular IOR Level"].default_value = spec
    m.diffuse_color = (*color, 1.0)
    return m

def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

MAT = {
    "coated": principled("KIT_coated_grey", srgb("7C858B"), 0.55, 0.0, 0.45),
    "coated_dark": principled("KIT_coated_grey_dark", srgb("666F75"), 0.58, 0.0, 0.45),
    "graphite": principled("KIT_graphite", srgb("2B2F33"), 0.70, 0.0, 0.35),
    "metal": principled("KIT_bare_metal", srgb("A9AEB2"), 0.35, 1.0),
    "floor": principled("KIT_floor", srgb("5E6469"), 0.65, 0.0, 0.4),
    "line": principled("KIT_line_white", srgb("D9DCDD"), 0.60, 0.0, 0.4),
    "safety": principled("KIT_safety_orange", srgb("B4521E"), 0.50, 0.0, 0.45),
}

# ------------------------------------------------------------------ geometry helpers
class Builder:
    """Accumulates parts into one bmesh with per-face material slots."""
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.slots = []

    def slot(self, key):
        m = MAT[key]
        if m not in self.slots: self.slots.append(m)
        return self.slots.index(m)

    def box(self, x0, y0, z0, x1, y1, z1, mat, bevel=0.0):
        bm = self.bm
        before = set(bm.faces)
        res = bmesh.ops.create_cube(bm, size=1.0)
        verts = res["verts"]
        sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
        bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=verts)
        bmesh.ops.translate(bm, vec=Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), verts=verts)
        faces = [f for f in bm.faces if f not in before]
        if bevel > 0.0:
            edges = list({e for f in faces for e in f.edges})
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect='EDGES', profile=0.5)
            faces = [f for f in bm.faces if f not in before]
        idx = self.slot(mat)
        for f in faces: f.material_index = idx
        return faces

    def cyl(self, cx, cy, cz, r, depth, axis, mat, segments=8):
        bm = self.bm
        before = set(bm.faces)
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r, radius2=r, depth=depth)
        verts = res["verts"]
        rot = {'x': Matrix.Rotation(math.radians(90), 3, 'Y'), 'y': Matrix.Rotation(math.radians(90), 3, 'X'), 'z': Matrix.Identity(3)}[axis]
        bmesh.ops.rotate(bm, verts=verts, cent=Vector((0, 0, 0)), matrix=rot)
        bmesh.ops.translate(bm, vec=Vector((cx, cy, cz)), verts=verts)
        idx = self.slot(mat)
        for f in bm.faces:
            if f not in before: f.material_index = idx

    def finish(self, col=COL_MODULES):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.slots: me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        col.objects.link(ob)
        # Flat shading with sharp hard edges; bevel faces carry the highlights.
        for p in me.polygons: p.use_smooth = False
        # Box-projected UVs at 1 UV unit = 1 m so tiling textures keep real-world scale.
        bpy.context.view_layer.objects.active = ob
        for o in bpy.context.selected_objects: o.select_set(False)
        ob.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.cube_project(cube_size=1.0, correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        ob.select_set(False)
        return ob

def bolts_row(b, xs, z, y=-0.012, r=0.018):
    for x in xs:
        b.cyl(x, y, z, r, 0.025, 'y', "metal", segments=6)

# ------------------------------------------------------------------ modules
def wall_segment(name, height):
    """4.0 m wall segment. Inner face y=0, depth 0.40 toward +y.
    Bands: plinth 0–0.35 (graphite, proud 0.05), service channels (recessed 0.06),
    armoured plates with a 0.02 raised frame, cap (graphite, proud 0.05)."""
    b = Builder(name)
    W, D = 4.0, 0.40
    x0, x1 = -W / 2, W / 2
    b.box(x0, -0.05, 0.0, x1, D, 0.35, "graphite", 0.01)            # kick plinth
    cap_h = 0.12 if height <= 4.5 else 0.25
    b.box(x0, -0.05, height - cap_h, x1, D, height, "graphite", 0.01)  # cap
    if height <= 4.5:
        bands = [(0.35, 2.40, "coated"), (2.60, height - cap_h, "coated_dark")]
        channels = [(2.40, 2.60)]
    else:
        bands = [(0.35, 2.40, "coated"), (2.60, 4.20, "coated_dark"), (4.40, height - cap_h, "coated")]
        channels = [(2.40, 2.60), (4.20, 4.40)]
    for (z0, z1, mat) in bands:
        b.box(x0 + 0.005, 0.02, z0, x1 - 0.005, D, z1, mat, 0.012)    # plate body, 5 mm seam each side
        # raised armour frame 0.02 proud on the inner face
        t = 0.10
        b.box(x0 + 0.03, 0.0, z0 + 0.04, x1 - 0.03, 0.02, z0 + 0.04 + t, mat, 0.006)
        b.box(x0 + 0.03, 0.0, z1 - 0.04 - t, x1 - 0.03, 0.02, z1 - 0.04, mat, 0.006)
        b.box(x0 + 0.03, 0.0, z0 + 0.04, x0 + 0.03 + t, 0.02, z1 - 0.04, mat, 0.006)
        b.box(x1 - 0.03 - t, 0.0, z0 + 0.04, x1 - 0.03, 0.02, z1 - 0.04, mat, 0.006)
    for (z0, z1) in channels:
        b.box(x0, 0.06, z0, x1, D, z1, "graphite")                     # recessed service channel
        bolts_row(b, [-1.75, -0.65, 0.65, 1.75], z0 + 0.10, y=0.045, r=0.022)
    return b.finish()

def column(name, height):
    """Armoured column 0.60 (x) × 0.70 (y), centred on the wall line (y=0), base 0.5 graphite,
    horizontal sleeve joints every 1.0 m, cap plate."""
    b = Builder(name)
    hw, hd = 0.30, 0.35
    b.box(-hw - 0.03, -hd - 0.03, 0.0, hw + 0.03, hd + 0.03, 0.50, "graphite", 0.015)
    z = 0.50
    while z < height - 0.15 - 0.001:
        z1 = min(z + 1.0, height - 0.15)
        b.box(-hw, -hd, z + 0.012, hw, hd, z1 - 0.012, "coated", 0.02)
        b.box(-hw + 0.02, -hd + 0.02, z1 - 0.012, hw - 0.02, hd - 0.02, z1 + 0.012, "graphite")
        z = z1
    b.box(-hw - 0.04, -hd - 0.04, height - 0.15, hw + 0.04, hd + 0.04, height, "graphite", 0.012)
    for zz in (0.75, height - 0.40):
        bolts_row(b, [-0.18, 0.18], zz, y=-hd - 0.006, r=0.02)
    return b.finish()

def floor_tile(name):
    """2.0 × 2.0 × 0.12 flush metal floor plate, top at z=0. One fine sanding groove
    (0.012 × 0.006) across the middle and four countersunk fixing holes; 4 mm chamfer so
    the 2 m grid reads at distance without a busy checkerboard."""
    b = Builder(name)
    b.box(-1.0, -1.0, -0.12, 1.0, 1.0, -0.006, "floor", 0.0)
    b.box(-0.997, -0.997, -0.006, 0.997, -0.006, 0.0, "floor", 0.002)
    b.box(-0.997, 0.006, -0.006, 0.997, 0.997, 0.0, "floor", 0.002)
    for (x, y) in ((-0.88, -0.88), (0.88, -0.88), (-0.88, 0.88), (0.88, 0.88)):
        b.cyl(x, y, 0.0005, 0.016, 0.002, 'z', "graphite", segments=8)
    return b.finish()

def floodlight_mast(name, height=12.0):
    """Yard floodlight mast: 0.30 square steel tube on a bolted base plate, a cross arm with
    four lamp housings aimed down into the yard (lamp faces = bare metal rims + graphite
    housings; emissive glass is not modelled so the lamps never fake light)."""
    b = Builder(name)
    b.box(-0.45, -0.45, 0.0, 0.45, 0.45, 0.05, "graphite", 0.01)          # base plate
    for (x, y) in ((-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)):
        b.cyl(x, y, 0.07, 0.025, 0.05, 'z', "metal", 6)
    b.box(-0.15, -0.15, 0.05, 0.15, 0.15, height, "coated_dark", 0.015)    # shaft
    b.box(-0.2, -0.2, 2.5, 0.2, 0.2, 2.75, "graphite", 0.01)               # service collar
    b.box(-1.6, -0.08, height - 0.35, 1.6, 0.08, height - 0.2, "metal", 0.01)   # cross arm
    for x in (-1.3, -0.45, 0.45, 1.3):
        b.box(x - 0.28, -0.42, height - 0.75, x + 0.28, -0.08, height - 0.25, "graphite", 0.02)  # housing
        b.box(x - 0.26, -0.44, height - 0.73, x + 0.26, -0.42, height - 0.27, "metal", 0.005)   # rim
    return b.finish()

def canopy(name, width=16.0, depth=5.0, height=4.2):
    """Firing-line shelter: four armoured posts, two primary beams, purlins and a thin roof
    deck with drip edge. Origin at floor centre; spans x=±width/2, y=0..depth (toward +y)."""
    b = Builder(name)
    hw = width / 2
    for x in (-hw + 0.3, hw - 0.3):
        for y in (0.4, depth - 0.4):
            b.box(x - 0.18, y - 0.18, 0.0, x + 0.18, y + 0.18, 0.4, "graphite", 0.01)
            b.box(x - 0.13, y - 0.13, 0.4, x + 0.13, y + 0.13, height - 0.35, "coated", 0.012)
    for y in (0.4, depth - 0.4):
        b.box(-hw, y - 0.12, height - 0.45, hw, y + 0.12, height - 0.12, "coated_dark", 0.01)   # primary beams
    x = -hw + 0.3
    while x <= hw - 0.3 + 0.001:
        b.box(x - 0.05, 0.0, height - 0.12, x + 0.05, depth, height - 0.02, "metal", 0.005)  # purlins
        x += 1.85
    b.box(-hw - 0.15, -0.15, height - 0.02, hw + 0.15, depth + 0.15, height + 0.06, "coated_dark", 0.01)  # deck
    b.box(-hw - 0.15, depth + 0.15, height - 0.10, hw + 0.15, depth + 0.17, height + 0.06, "graphite")   # drip edge (target side)
    return b.finish()

def lane_line(name, length):
    b = Builder(name)
    b.box(-length / 2, -0.05, 0.0, length / 2, 0.05, 0.004, "line")
    return b.finish()

def target_bay(name):
    """Armoured target backdrop: outer envelope 4.0 × 3.0 × 0.30 (matches gameplay collision,
    centred at y=0.15 behind the inner face line), 0.12 square-tube frame, armour plate,
    middle rail, two rear braces down to bolted feet."""
    b = Builder(name)
    W, H, T = 4.0, 3.0, 0.30
    t = 0.12
    # frame (bare metal tubes)
    b.box(-W / 2, 0.0, 0.0, -W / 2 + t, t, H, "metal", 0.01)
    b.box(W / 2 - t, 0.0, 0.0, W / 2, t, H, "metal", 0.01)
    b.box(-W / 2, 0.0, H - t, W / 2, t, H, "metal", 0.01)
    b.box(-W / 2, 0.0, 0.10, W / 2, t, 0.10 + t, "metal", 0.01)
    # armour plate set 0.03 behind the frame front
    b.box(-W / 2 + t, 0.03, 0.10 + t, W / 2 - t, 0.11, H - t, "coated", 0.008)
    b.box(-W / 2 + t, 0.02, 1.45, W / 2 - t, 0.03, 1.55, "graphite")        # middle seam rail
    # rear braces + feet within the 0.30 depth envelope, feet extend back to 0.60
    for x in (-1.3, 1.3):
        b.box(x - 0.05, t, 0.0, x + 0.05, T, 2.6, "metal", 0.008)
        b.box(x - 0.30, 0.0, 0.0, x + 0.30, 0.60, 0.03, "graphite", 0.006)
        b.cyl(x - 0.2, 0.45, 0.035, 0.02, 0.02, 'z', "metal", 6)
        b.cyl(x + 0.2, 0.45, 0.035, 0.02, 0.02, 'z', "metal", 6)
    bolts_row(b, [-1.6, -0.55, 0.55, 1.6], 1.50, y=0.015, r=0.02)
    return b.finish()

def platform(name, height):
    """3.0 × 3.0 steel-clad platform, origin bottom centre. Clad panels with 1 m vertical seams,
    bare-metal corner angles, deck plate with an orange safety edge, rear ladder (h >= 1)."""
    b = Builder(name)
    L = 1.5
    deck = 0.05
    if height < 0.5:
        b.box(-L, -L, 0.0, L, L, height, "coated_dark", 0.01)
    else:
        b.box(-L, -L, 0.0, L, L, 0.25, "graphite", 0.01)                        # base course
        b.box(-L + 0.02, -L + 0.02, 0.25, L - 0.02, L - 0.02, height - deck, "coated", 0.012)
        # vertical seams every 1.0 m on all four faces (recessed graphite strips)
        for s in (-0.5, 0.5):
            b.box(s - 0.008, -L + 0.012, 0.25, s + 0.008, -L + 0.03, height - deck, "graphite")
            b.box(s - 0.008, L - 0.03, 0.25, s + 0.008, L - 0.012, height - deck, "graphite")
            b.box(-L + 0.012, s - 0.008, 0.25, -L + 0.03, s + 0.008, height - deck, "graphite")
            b.box(L - 0.03, s - 0.008, 0.25, L - 0.012, s + 0.008, height - deck, "graphite")
        for (cx, cy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            x = cx * (L - 0.04)
            y = cy * (L - 0.04)
            b.box(x - 0.05, y - 0.05, 0.0, x + 0.05, y + 0.05, height, "metal", 0.006)
        # ladder on the rear (+y) face
        for rx in (-0.22, 0.22):
            b.box(rx - 0.025, L + 0.12, 0.0, rx + 0.025, L + 0.17, height + 0.9, "metal", 0.006)
            b.box(rx - 0.025, L, height - 0.3, rx + 0.025, L + 0.17, height - 0.25, "metal")
        r = 0.30
        while r < height + 0.01:
            b.box(-0.22, L + 0.13, r, 0.22, L + 0.16, r + 0.03, "metal")
            r += 0.30
    # deck plate and safety edge band
    b.box(-L, -L, height - deck, L, L, height, "coated_dark", 0.01)
    e = 0.15
    b.box(-L, -L, height, L, -L + e, height + 0.004, "safety")
    b.box(-L, L - e, height, L, L, height + 0.004, "safety")
    b.box(-L, -L + e, height, -L + e, L - e, height + 0.004, "safety")
    b.box(L - e, -L + e, height, L, L - e, height + 0.004, "safety")
    return b.finish()

# ------------------------------------------------------------------ build modules
modules = {}
modules["TY_W4_45"] = wall_segment("TY_W4_45", 4.5)
modules["TY_W4_60"] = wall_segment("TY_W4_60", 6.0)
modules["TY_C_51"] = column("TY_C_51", 5.1)
modules["TY_C_66"] = column("TY_C_66", 6.6)
modules["TY_F2"] = floor_tile("TY_F2")
modules["TY_LINE_31"] = lane_line("TY_LINE_31", 31.0)
modules["TY_BAY"] = target_bay("TY_BAY")
for h in (0.15, 1, 2, 3, 4):
    key = "TY_PF_%s" % (str(h).replace(".", "_"))
    modules[key] = platform(key, float(h))
modules["TY_MAST_12"] = floodlight_mast("TY_MAST_12", 12.0)
modules["TY_CANOPY"] = canopy("TY_CANOPY")

# lay the masters out in a row for inspection (x spacing 6 m, y = 30 m away from assemblies)
for i, (k, ob) in enumerate(modules.items()):
    ob.location = Vector((i * 6.0 - 30.0, 60.0, 0.0))

# ------------------------------------------------------------------ assemblies (linked duplicates)
# Godot coordinates (x, z) map to Blender (x, -z).
def place(key, gx, gz, col, rot_deg=0.0, gy=0.0):
    src = modules[key]
    ob = bpy.data.objects.new("%s@%.1f_%.1f" % (key, gx, gz), src.data)
    ob.location = Vector((gx, -gz, gy))
    ob.rotation_euler = (0.0, 0.0, math.radians(rot_deg))
    col.objects.link(ob)
    return ob

def shell(col):
    # floor 32 × 48: tiles centred on odd metres
    for ix in range(16):
        for iz in range(24):
            place("TY_F2", -15.0 + 2 * ix, -35.0 + 2 * iz, col)
    for z in (-32, -24, -16, -8, 0, 8):
        place("TY_LINE_31", 0.0, z, col)
    # back wall (z = -36, faces the player): inner face toward +Z_godot == -Y_blender  -> no rotation
    for k in range(8):
        place("TY_W4_60", -14.0 + 4 * k, -36.0, col)
    # front wall (z = 12) faces -Z_godot -> rotate 180
    for k in range(8):
        place("TY_W4_45", -14.0 + 4 * k, 12.0, col, 180.0)
    # side walls: left x=-16 faces +X, right x=16 faces -X
    for k in range(12):
        z = -34.0 + 4 * k
        place("TY_W4_45", -16.0, z, col, 90.0)    # inner face (-Y local) turned to +X
        place("TY_W4_45", 16.0, z, col, -90.0)    # inner face turned to -X
    for k in range(9):
        place("TY_C_66", -16.0 + 4 * k, -36.0, col)
        place("TY_C_51", -16.0 + 4 * k, 12.0, col)
    for k in range(1, 12):
        place("TY_C_51", -16.0, -36.0 + 4 * k, col, 90.0)
        place("TY_C_51", 16.0, -36.0 + 4 * k, col, 90.0)
    # floodlight masts outside the walls (behind the back corners and mid-sides), arms facing in
    for (gx, gz, rot) in ((-15.0, -38.0, 0.0), (15.0, -38.0, 0.0), (-18.0, -14.0, 90.0), (18.0, -14.0, -90.0)):
        place("TY_MAST_12", gx, gz, col, rot)
    # firing-line shelter behind the spawn: z = 7 .. 12 (Godot), 4.2 m clear height so the
    # deck stays above the default view and only its shadow frames the foreground
    place("TY_CANOPY", 0.0, 12.0, col)

shell(COL_REACTION)
for x in (-10, -5, 0, 5, 10):
    # gameplay box: centre (x, 1.5, -12), 4×3×0.3 -> inner face at z = -11.85
    place("TY_BAY", float(x), -11.85, COL_REACTION)
shell(COL_ELEVATION)
for (x, z, h) in ((-10, -8, 0.15), (-5, -16, 2), (0, -24, 4), (5, -12, 1), (10, -20, 3)):
    place("TY_PF_%s" % str(h).replace(".", "_"), float(x), float(z), COL_ELEVATION)
COL_ELEVATION.hide_render = True
COL_ELEVATION.hide_viewport = True

# ------------------------------------------------------------------ export GLBs
def export_module(ob):
    for o in bpy.context.view_layer.objects: o.select_set(False)
    loc = ob.location.copy()
    ob.location = Vector((0, 0, 0))
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(EXPORT_DIR, ob.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT',
                              export_texcoords=True, export_normals=True)
    ob.location = loc
    ob.select_set(False)
    return path

exported = [export_module(ob) for ob in modules.values()]

# ------------------------------------------------------------------ cameras, light, renders
def add_camera(name, loc, look, ortho=0.0, lens=18.0):
    cam = bpy.data.cameras.new(name)
    if ortho > 0:
        cam.type = 'ORTHO'
        cam.ortho_scale = ortho
    else:
        cam.lens_unit = 'FOV'
        cam.angle = math.radians(95.0)  # horizontal FOV like the game
    cam.clip_end = 400.0
    ob = bpy.data.objects.new(name, cam)
    COL_CAM.objects.link(ob)
    ob.location = Vector(loc)
    d = Vector(look) - Vector(loc)
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return ob

sun_data = bpy.data.lights.new("Sun", 'SUN')
sun_data.energy = 3.2
sun_data.angle = math.radians(1.2)
sun_data.color = (1.0, 0.93, 0.84)
sun = bpy.data.objects.new("Sun", sun_data)
COL_CAM.objects.link(sun)
sun.rotation_euler = (math.radians(62), 0.0, math.radians(-35))

world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.55, 0.62, 0.70, 1.0)
bg.inputs[1].default_value = 0.9

cams = {
    "player_view": add_camera("CAM_player_view", (0.0, -10.0, 1.7), (0.0, 30.0, 1.4)),
    "ortho_oblique": add_camera("CAM_ortho_oblique", (40.0, -40.0, 45.0), (0.0, 12.0, 0.0), ortho=62.0),
    "ortho_top": add_camera("CAM_ortho_top", (0.0, 12.0, 80.0), (0.0, 12.0001, 0.0), ortho=56.0),
    "birdseye": add_camera("CAM_birdseye", (18.0, -26.0, 34.0), (0.0, 12.0, 0.0)),
}
cams["birdseye"].data.angle = math.radians(60.0)

def set_engine():
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = eng
            return eng
        except Exception:
            pass
    scene.render.engine = 'BLENDER_WORKBENCH'
    return 'BLENDER_WORKBENCH'

engine = set_engine()
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.film_transparent = False
try:
    scene.view_settings.view_transform = 'AgX'
except Exception:
    pass
renders = []
for layout, col_on, col_off in (("reaction", COL_REACTION, COL_ELEVATION), ("elevation", COL_ELEVATION, COL_REACTION)):
    col_on.hide_render = False
    col_off.hide_render = True
    COL_MODULES.hide_render = True
    for key, cam in cams.items():
        scene.camera = cam
        out = os.path.join(RENDER_DIR, "%s_%s.png" % (layout, key))
        scene.render.filepath = out
        try:
            bpy.ops.render.render(write_still=True)
            renders.append(out)
        except Exception as e:
            print("RENDER_FAIL", key, e)
COL_MODULES.hide_render = False
COL_ELEVATION.hide_render = True

# ------------------------------------------------------------------ save + report
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
tri = {}
for k, ob in modules.items():
    me = ob.data
    me.calc_loop_triangles()
    tri[k] = len(me.loop_triangles)
print("KIT_ENGINE", engine)
print("KIT_TRIS", tri)
print("KIT_EXPORTS", len(exported))
print("KIT_RENDERS", len(renders))
print("KIT_SAVED", BLEND_PATH)
