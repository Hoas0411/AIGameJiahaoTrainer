# Segmented Cover Set — Blender build script (Blender 5.1, headless or Text Editor).
# Produces segmented_cover_set.blend next to this file, one GLB per module in
# game/assets/models/segmented_cover_set_20261009/, and EEVEE renders in renders/.
# Every module's visible surface stays inside the gameplay collision box it replaces
# (see 设计说明.md §2). Origin: floor centre. Blender Z-up -> glTF Y-up.
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
EXPORT_DIR = os.path.join(GAME, "assets", "models", "segmented_cover_set_20261009")
RENDER_DIR = os.path.join(HERE, "renders")
BLEND_PATH = os.path.join(HERE, "segmented_cover_set.blend")
os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(RENDER_DIR, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'

def collection(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

COL_MODULES = collection("Modules")
COL_LAYOUT = collection("Layout_BayA")
COL_CAM = collection("Cameras_Lights")

def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def principled(name, color, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*color, 1.0)
    return m

# Slot names are the import keys: Godot maps them to external .tres materials
# (SC_body_* -> the level's Kenney grid materials, KIT_* -> training_yard materials).
MAT = {
    "body_light": principled("SC_body_light", srgb("C4D0D8"), 0.9),
    "body_blue": principled("SC_body_blue", srgb("61798F"), 0.9),
    "body_dark": principled("SC_body_dark", srgb("3B4652"), 0.9),
    "graphite": principled("KIT_graphite", srgb("2B2F33"), 0.70),
    "metal": principled("KIT_bare_metal", srgb("A9AEB2"), 0.35, 1.0),
    "safety": principled("KIT_safety_orange", srgb("B4521E"), 0.50),
}

class Builder:
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
        bmesh.ops.scale(bm, vec=Vector((x1 - x0, y1 - y0, z1 - z0)), verts=verts)
        bmesh.ops.translate(bm, vec=Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), verts=verts)
        faces = [f for f in bm.faces if f not in before]
        if bevel > 0.0:
            edges = list({e for f in faces for e in f.edges})
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect='EDGES', profile=0.5)
            faces = [f for f in bm.faces if f not in before]
        idx = self.slot(mat)
        for f in faces: f.material_index = idx

    def finish(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.slots: me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        COL_MODULES.objects.link(ob)
        for p in me.polygons: p.use_smooth = False
        bpy.context.view_layer.objects.active = ob
        for o in bpy.context.selected_objects: o.select_set(False)
        ob.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.cube_project(cube_size=1.0, correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        ob.select_set(False)
        return ob

def barrier(name, W, D, H, body, plinth, band, cap, inset, guard):
    """Solid training barrier inside the W×D×H envelope: graphite plinth / waist band / cap
    flush with the envelope, body panels inset, bare-metal corner guards flush on all four
    vertical edges (they mark the peek edges with a clean highlight line)."""
    b = Builder(name)
    hw, hd = W / 2, D / 2
    b.box(-hw, -hd, 0.0, hw, hd, plinth, "graphite", 0.008)
    b.box(-hw + inset, -hd + inset, plinth, hw - inset, hd - inset, H - cap, body, 0.004)
    b.box(-hw + 0.004, -hd + 0.004, band[0], hw - 0.004, hd - 0.004, band[1], "graphite", 0.006)
    b.box(-hw, -hd, H - cap, hw, hd, H, "graphite", 0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = sorted((sx * hw, sx * (hw - guard)))
            y0, y1 = sorted((sy * hd, sy * (hd - guard)))
            b.box(x0, y0, plinth, x1, y1, H - cap, "metal", 0.006)
    return b.finish()

def step(name, W, D, H):
    """Jump step: dark body, bare-metal tread plate, graphite grip strips across the tread,
    dark-orange nosing on both long edges."""
    b = Builder(name)
    hw, hd = W / 2, D / 2
    plate = 0.036
    b.box(-hw, -hd, 0.0, hw, hd, H - plate, "body_dark", 0.012)
    b.box(-hw + 0.02, -hd + 0.02, H - plate, hw - 0.02, hd - 0.02, H - 0.010, "metal", 0.004)
    for k in range(5):
        y = -0.42 + k * 0.21
        b.box(-hw + 0.06, y - 0.018, H - 0.010, hw - 0.06, y + 0.018, H, "graphite")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - 0.05)))
        b.box(x0, -hd, H - plate - 0.004, x1, hd, H - 0.010, "safety", 0.003)
    return b.finish()

modules = {
    "SC_COVER_TALL": barrier("SC_COVER_TALL", 2.608, 2.149, 1.906, "body_light", 0.10, (0.86, 0.96), 0.126, 0.004, 0.10),
    "SC_COVER_LOW": barrier("SC_COVER_LOW", 1.249, 1.023, 1.254, "body_blue", 0.08, (0.58, 0.66), 0.084, 0.004, 0.08),
    "SC_STEP": step("SC_STEP", 0.707, 1.101, 0.607),
}
for i, ob in enumerate(modules.values()):
    ob.location = Vector((i * 4.0 - 4.0, 40.0, 0.0))

# Bay A layout (Godot x,z -> Blender x,-z), for renders only.
def place(key, gx, gz):
    ob = bpy.data.objects.new("%s@%.2f_%.2f" % (key, gx, gz), modules[key].data)
    ob.location = Vector((gx, -gz, 0.0))
    COL_LAYOUT.objects.link(ob)

place("SC_COVER_TALL", 2.65, -8.0)
place("SC_COVER_TALL", 5.35, -8.0)
for x in (2.7518, 4.0, 5.2482):
    place("SC_COVER_LOW", x, -18.0)
place("SC_STEP", 6.0, -2.0)
fl = bpy.data.meshes.new("Floor")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=14.0)
bm.to_mesh(fl); bm.free()
fl.materials.append(principled("Floor_preview", srgb("8C969E"), 0.9))
flo = bpy.data.objects.new("Floor_preview", fl)
flo.location = Vector((4.0, 12.0, 0.0))
COL_LAYOUT.objects.link(flo)

def export_module(ob):
    for o in bpy.context.view_layer.objects: o.select_set(False)
    loc = ob.location.copy()
    ob.location = Vector((0, 0, 0))
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(EXPORT_DIR, ob.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_texcoords=True, export_normals=True)
    ob.location = loc
    ob.select_set(False)
    return path

exported = [export_module(ob) for ob in modules.values()]

def add_camera(name, loc, look, ortho=0.0):
    cam = bpy.data.cameras.new(name)
    if ortho > 0:
        cam.type = 'ORTHO'; cam.ortho_scale = ortho
    else:
        cam.lens_unit = 'FOV'; cam.angle = math.radians(90.0)
    ob = bpy.data.objects.new(name, cam)
    COL_CAM.objects.link(ob)
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob

sun_data = bpy.data.lights.new("Sun", 'SUN')
sun_data.energy = 3.0
sun_data.angle = math.radians(1.5)
sun = bpy.data.objects.new("Sun", sun_data)
COL_CAM.objects.link(sun)
sun.rotation_euler = (math.radians(52), 0.0, math.radians(-28))
world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs[0].default_value = (0.55, 0.64, 0.74, 1.0)

cams = {
    "player_view": add_camera("CAM_player_view", (3.0, 6.0, 1.7), (4.0, 18.0, 1.0)),
    "ortho_oblique": add_camera("CAM_ortho_oblique", (16.0, -2.0, 14.0), (4.0, 12.0, 0.6), ortho=16.0),
    "ortho_top": add_camera("CAM_ortho_top", (4.0, 12.0, 30.0), (4.0, 12.0001, 0.0), ortho=18.0),
    "modules": add_camera("CAM_modules", (6.0, 34.0, 3.2), (0.0, 40.0, 0.8)),
}
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
    try:
        scene.render.engine = eng; break
    except Exception:
        pass
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
try: scene.view_settings.view_transform = 'AgX'
except Exception: pass
renders = []
for key, cam in cams.items():
    COL_MODULES.hide_render = key != "modules"
    COL_LAYOUT.hide_render = key == "modules"
    scene.camera = cam
    out = os.path.join(RENDER_DIR, key + ".png")
    scene.render.filepath = out
    try:
        bpy.ops.render.render(write_still=True); renders.append(out)
    except Exception as e:
        print("RENDER_FAIL", key, e)
COL_MODULES.hide_render = False
COL_LAYOUT.hide_render = False
scene.camera = cams["player_view"]
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

tri, bounds = {}, {}
for k, ob in modules.items():
    me = ob.data
    me.calc_loop_triangles()
    tri[k] = len(me.loop_triangles)
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    bounds[k] = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4), round(min(zs), 4)]
print("SC_ENGINE", scene.render.engine)
print("SC_TRIS", tri)
print("SC_BOUNDS", bounds)
print("SC_EXPORTS", len(exported))
print("SC_RENDERS", len(renders))
print("SC_SAVED", BLEND_PATH)
