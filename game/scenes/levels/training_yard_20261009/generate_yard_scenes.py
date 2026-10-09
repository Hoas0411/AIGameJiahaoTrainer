# Assembles the Blender-made Training Yard Kit into Godot scenes (visual art only; gameplay
# collision stays in each level scene). Re-run after moving modules: python generate_yard_scenes.py
import math, os
HERE = os.path.dirname(os.path.abspath(__file__))
KIT = "res://assets/models/training_yard_kit_20261009/"
MODS = ["TY_F2", "TY_LINE_31", "TY_W4_45", "TY_W4_60", "TY_C_51", "TY_C_66", "TY_BAY", "TY_PF_0_15", "TY_PF_1", "TY_PF_2", "TY_PF_3", "TY_PF_4", "TY_MAST_12", "TY_CANOPY"]

def scene(name, extras):
    lines = []
    lines.append('[gd_scene format=3]\n')
    for m in MODS:
        lines.append('[ext_resource type="PackedScene" path="%s%s.glb" id="%s"]' % (KIT, m, m))
    lines.append('')
    lines.append('[node name="%s" type="Node3D"]' % name)
    lines.append('metadata/kit = "training_yard_kit_20261009"\n')
    for g in ("Floor", "Lines", "Walls", "Columns", "Features"):
        lines.append('[node name="%s" type="Node3D" parent="."]\n' % g)
    def inst(group, node, mod, x, y, z, ry=0.0):
        lines.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % (node, group, mod))
        lines.append('position = Vector3(%g, %g, %g)' % (x, y, z))
        if ry: lines.append('rotation = Vector3(0, %.9f, 0)' % math.radians(ry))
        lines.append('')
    for ix in range(16):
        for iz in range(24):
            inst("Floor", "floor_%d_%d" % (ix, iz), "TY_F2", -15 + 2 * ix, 0, -35 + 2 * iz)
    for z in (-32, -24, -16, -8, 0, 8):
        inst("Lines", "line_z%d" % z, "TY_LINE_31", 0, 0, z)
    for k in range(8):
        inst("Walls", "back_%d" % k, "TY_W4_60", -14 + 4 * k, 0, -36)
        inst("Walls", "front_%d" % k, "TY_W4_45", -14 + 4 * k, 0, 12, 180)
    for k in range(12):
        z = -34 + 4 * k
        inst("Walls", "left_%d" % k, "TY_W4_45", -16, 0, z, 90)
        inst("Walls", "right_%d" % k, "TY_W4_45", 16, 0, z, -90)
    for k in range(9):
        inst("Columns", "back_c%d" % k, "TY_C_66", -16 + 4 * k, 0, -36)
        inst("Columns", "front_c%d" % k, "TY_C_51", -16 + 4 * k, 0, 12)
    for k in range(1, 12):
        inst("Columns", "left_c%d" % k, "TY_C_51", -16, 0, -36 + 4 * k, 90)
        inst("Columns", "right_c%d" % k, "TY_C_51", 16, 0, -36 + 4 * k, 90)
    for i, (gx, gz, rot) in enumerate(((-15, -38, 0), (15, -38, 0), (-18, -14, 90), (18, -14, -90))):
        inst("Features", "mast_%d" % i, "TY_MAST_12", gx, 0, gz, rot)
    inst("Features", "canopy", "TY_CANOPY", 0, 0, 12)
    for e in extras: inst("Features", *e)
    open(os.path.join(HERE, name.lower() + ".tscn"), "w").write("\n".join(lines) + "\n")

scene("Yard_Reaction", [("bay_%d" % i, "TY_BAY", x, 0, -11.85) for i, x in enumerate((-10, -5, 0, 5, 10))])
scene("Yard_Elevation", [
    ("platform_0", "TY_PF_0_15", -10, -0.075, -8),
    ("platform_1", "TY_PF_2", -5, 0, -16),
    ("platform_2", "TY_PF_4", 0, 0, -24),
    ("platform_3", "TY_PF_1", 5, 0, -12),
    ("platform_4", "TY_PF_3", 10, 0, -20),
])
print("scenes written")
