"""Builds a realistic, rigged game character with MakeHuman (MPFB2, CC0) in headless
Blender and exports it as GLB for Godot.

Usage: python3 build_character.py <out.glb> <json params>
Params: gender, age, muscle, weight, height, race{african,asian,caucasian},
        skin [r,g,b], hair [r,g,b], shirt [r,g,b], pants [r,g,b], shoes [r,g,b],
        sleeves ("short"/"long"), decimate (0..1)
"""
import sys, json, math, importlib, os  # noqa
import bpy, bmesh
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from setup_mpfb import enable

OUT = sys.argv[1]
P = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
TEX_DIR = "/tmp/mpfb2/src/mpfb/data/textures"
GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FABRIC_N = GAME + "/assets/textures/fabric_normal.jpg"
DENIM_A = GAME + "/assets/textures/denim_albedo.jpg"
WORK = "/tmp/chargen/work"
os.makedirs(WORK, exist_ok=True)

pkg = enable()
HumanService = importlib.import_module(pkg + ".services.humanservice").HumanService
TargetService = importlib.import_module(pkg + ".services.targetservice").TargetService

# Start from an empty scene.
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

macro = TargetService.get_default_macro_info_dict()
for k in ["gender", "age", "muscle", "weight", "height", "proportions"]:
    if k in P:
        macro[k] = P[k]
if "race" in P:
    macro["race"] = P["race"]
human = HumanService.create_human(macro_detail_dict=macro, feet_on_ground=True)
rig = HumanService.add_builtin_rig(human, "game_engine")
for m in list(human.modifiers):
    if m.type == 'MASK':
        human.modifiers.remove(m)

# Bake the body shape into the mesh (no shape keys in the game file).
bpy.context.view_layer.objects.active = human
if human.data.shape_keys:
    human.shape_key_add(name="final", from_mix=True)
    keys = human.data.shape_keys.key_blocks
    final = keys["final"]
    for v, sk in zip(human.data.vertices, final.data):
        v.co = sk.co
    human.shape_key_clear()

vg = {g.name: g.index for g in human.vertex_groups}


def weight(v, name):
    gi = vg.get(name)
    if gi is None:
        return 0.0
    for g in v.groups:
        if g.group == gi:
            return g.weight
    return 0.0


def wsum(v, names):
    return sum(weight(v, n) for n in names)


mesh = human.data
verts = mesh.vertices
is_body = np.array([weight(v, "body") > 0.5 for v in verts])
is_eye = np.array([weight(v, "helper-l-eye") + weight(v, "helper-r-eye") > 0.5 for v in verts])
eye_pts = [v.co.copy() for i, v in enumerate(verts) if is_eye[i]]
EYE_Z = sum(p.z for p in eye_pts) / len(eye_pts)
EYE_Y = sum(p.y for p in eye_pts) / len(eye_pts)
EYE_X = sum(abs(p.x) for p in eye_pts) / len(eye_pts)
head_pts = [v.co for i, v in enumerate(verts) if is_body[i] and weight(v, "head") > 0.6]
HEAD_Y = sum(p.y for p in head_pts) / len(head_pts)


def hair_at(v):
    if weight(v, "head") < 0.5 or weight(v, "ears") > 0.2:
        return False
    c = v.co
    front = c.y < HEAD_Y - 0.035          # forehead side (face looks toward -Y)
    if front:
        return c.z > EYE_Z + 0.062 + max(0.0, 0.03 - abs(c.x)) * 0.25
    # Temples and sides come down to the top of the ear, the back a bit lower.
    back = c.y > HEAD_Y + 0.02
    return c.z > EYE_Z + (-0.03 if back else 0.015)


is_hair = np.array([is_body[i] and hair_at(v) for i, v in enumerate(verts)])

TORSO = ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "pelvis"]
UPPER = ["upperarm_l", "upperarm_r"]
LOWER_ARM = ["lowerarm_l", "lowerarm_r"]
LEGS = ["thigh_l", "thigh_r", "calf_l", "calf_r"]
FEET = ["foot_l", "foot_r", "ball_l", "ball_r"]
long_sleeves = P.get("sleeves", "short") == "long"

zs = np.array([v.co.z for v in verts])
waist_z = None


def region(v):
    """Which garment covers this body vertex (None = bare skin)."""
    t = wsum(v, TORSO)
    ua = wsum(v, UPPER)
    la = wsum(v, LOWER_ARM)
    lg = wsum(v, LEGS)
    ft = wsum(v, FEET)
    neck = weight(v, "neck_01") + weight(v, "head")
    hands = sum(weight(v, n) for n in vg if n.startswith(("hand_", "index", "middle", "ring", "pinky", "thumb")))
    if ft > 0.3:
        return "shoes"
    if hands > 0.3 or neck > 0.45:
        return None
    if lg > 0.5:
        return "pants"
    # Pelvis area below the waist line belongs to the pants.
    if weight(v, "pelvis") > 0.4 and v.co.z < WAIST:
        return "pants"
    if ua + la > 0.5:
        side = "l" if v.co.x > 0 else "r"
        a, b = ARM[side]
        t_arm = (v.co - a).dot(b - a) / (b - a).length_squared
        # Short sleeves end 40% down the upper arm; long ones at the wrist.
        return "shirt" if t_arm < (0.42 if not long_sleeves else 1.85) else None
    if t > 0.5:
        return "shirt"
    return None


# Waist height: a little above the hip joints.
hip_z = rig.data.bones["thigh_l"].head_local.z + rig.location.z
WAIST = hip_z + 0.12
ARM = {}
for side in ("l", "r"):
    bone = rig.data.bones["upperarm_" + side]
    ARM[side] = (bone.head_local + rig.location, bone.tail_local + rig.location)

regions = [region(v) if is_body[i] else None for i, v in enumerate(verts)]

# ---- Build garments by duplicating the covered faces and pushing them outward.
INFLATE = {"shirt": 0.010, "pants": 0.013, "shoes": 0.016}
SMOOTH = {"Shirt": 4, "Pants": 8, "Shoes": 18, "Hair": 3}


def build_part(name, keep_face, inflate, material):
    obj = human.copy()
    obj.data = human.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if not keep_face(f)]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    # Smoothing removes anatomy (muscles, toes) so garments read as fabric / shoes.
    for _ in range(SMOOTH.get(name, 0)):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    if inflate:
        for v in bm.verts:
            v.co += v.normal * inflate
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def mat(name, color, rough=0.8, image=None, normal=None, scale=1.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    uvmap = None
    if image or normal:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (scale, scale, 1.0)
        nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
        uvmap = mp.outputs["Vector"]
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image)
        nt.links.new(uvmap, tex.inputs["Vector"])
        if color != (1.0, 1.0, 1.0):
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(tex.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*color, 1.0)
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if normal:
        nimg = nt.nodes.new("ShaderNodeTexImage")
        nimg.image = bpy.data.images.load(normal)
        nimg.image.colorspace_settings.name = "Non-Color"
        nt.links.new(uvmap, nimg.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nimg.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def lin(c):
    """sRGB 0..1 to linear (Blender colour inputs are linear)."""
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


skin_rgb = P.get("skin", [0.78, 0.6, 0.48])

# ---- Skin texture painted in UV space from MakeHuman's region masks.
def make_skin_texture(path, base):
    from PIL import Image, ImageFilter
    S = 1024
    def mask(n):
        return np.asarray(Image.open(f"{TEX_DIR}/mpfb_{n}.jpg").convert("L").resize((S, S), Image.BILINEAR), dtype=np.float32) / 255.0
    rng = np.random.default_rng(7)
    noise = np.asarray(Image.fromarray((rng.random((S // 8, S // 8)) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), dtype=np.float32) / 255.0
    fine = np.asarray(Image.fromarray((rng.random((S, S)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
    col = np.ones((S, S, 3), np.float32) * np.array(base, np.float32)
    col *= (0.96 + noise[..., None] * 0.05) * (0.985 + fine[..., None] * 0.03)
    lips = mask("lips")[..., None]
    col = col * (1 - lips * 0.35) + np.array(base) * np.array([0.9, 0.64, 0.62]) * lips * 0.35
    lids = mask("eyelids")[..., None]
    col *= 1 - lids * 0.12
    face = mask("face")[..., None]
    col = col * (1 - face * 0.08) + col * np.array([1.06, 0.97, 0.95]) * face * 0.08   # warmer face
    for n in ["fingernails", "toenails"]:
        m = mask(n)[..., None]
        col = col * (1 - m * 0.6) + np.array([0.92, 0.78, 0.74]) * m * 0.6
    ears = mask("ears")[..., None]
    col *= 1 - ears * 0.04
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(path, quality=90)


skin_tex = f"{WORK}/skin_{abs(hash(tuple(skin_rgb))) % 10000}.jpg"
make_skin_texture(skin_tex, skin_rgb)


def paint_eyebrows(path, color):
    """Rasterises the faces above each eye into the skin texture with the hair colour."""
    from PIL import Image, ImageDraw, ImageFilter
    img = Image.open(path).convert("RGB")
    S = img.size[0]
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        if not all(is_body[i] for i in poly.vertices):
            continue
        c = sum((verts[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        dz = c.z - EYE_Z
        dx = abs(abs(c.x) - EYE_X)
        if 0.011 < dz < 0.021 - dx * 0.15 and dx < 0.026 and abs(c.x) > 0.011 and c.y < EYE_Y + 0.01:
            pts = [(uv[li].uv.x * S, (1.0 - uv[li].uv.y) * S) for li in poly.loop_indices]
            d.polygon(pts, fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(2.0))
    m = np.asarray(layer, np.float32)[..., None] / 255.0 * 0.7
    col = np.asarray(img, np.float32) / 255.0
    col = col * (1 - m) + np.array(color) * m
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(path, quality=90)


paint_eyebrows(skin_tex, P.get("hair", [0.1, 0.075, 0.06]))

M_SKIN = mat("skin", (1.0, 1.0, 1.0), 0.55, image=skin_tex)
M_SHIRT = mat("shirt", lin(P.get("shirt", [0.85, 0.85, 0.83])), 0.95, normal=FABRIC_N, scale=8.0)
pants_rgb = P.get("pants", [1, 1, 1])
M_PANTS = mat("pants", lin(pants_rgb) if pants_rgb != [1, 1, 1] else (1.0, 1.0, 1.0), 0.9, image=DENIM_A, normal=FABRIC_N, scale=6.0)
M_SHOES = mat("shoes", lin(P.get("shoes", [0.92, 0.92, 0.9])), 0.6)
M_HAIR = mat("hair", lin(P.get("hair", [0.1, 0.075, 0.06])), 0.7, normal=FABRIC_N, scale=20.0)
M_EYES = mat("eyes", (0.85, 0.85, 0.82), 0.1)

face_region = {}
for f in mesh.polygons:
    rs = [regions[i] for i in f.vertices]
    face_region[f.index] = rs


def covered_by(name, strict):
    def keep(f):
        rs = [regions[v.index] for v in f.verts]
        if strict:
            return all(r == name for r in rs)
        return any(r == name for r in rs)
    return keep


parts = []
parts.append(build_part("Shirt", covered_by("shirt", False), INFLATE["shirt"], M_SHIRT))
parts.append(build_part("Pants", covered_by("pants", False), INFLATE["pants"], M_PANTS))
shoes = build_part("Shoes", covered_by("shoes", False), 0.0, M_SHOES)
bm = bmesh.new()
bm.from_mesh(shoes.data)
for side in (1, -1):
    vs = [v for v in bm.verts if v.co.x * side > 0]
    old_faces = list({f for v in vs for f in v.link_faces})
    res = bmesh.ops.convex_hull(bm, input=vs)
    hull_faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.delete(bm, geom=[f for f in old_faces if f.is_valid and f not in hull_faces], context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.normal_update()
for v in bm.verts:
    v.co += v.normal * 0.008
    v.co.z = max(v.co.z, -0.005)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(shoes.data)
bm.free()
parts.append(shoes)
parts.append(build_part("Hair", lambda f: all(is_hair[v.index] for v in f.verts), 0.007, M_HAIR))
parts.append(build_part("Eyes", lambda f: all(is_eye[v.index] for v in f.verts), 0.0, M_EYES))


def skin_keep(f):
    idx = [v.index for v in f.verts]
    if not all(is_body[i] for i in idx):
        return False
    # Drop skin that is completely hidden under clothes (saves triangles, no poke-through).
    rs = [regions[i] for i in idx]
    return not all(r is not None for r in rs)


body = build_part("Body", skin_keep, 0.0, M_SKIN)
parts.append(body)

# Eye colours: iris and pupil painted by direction (eyes look along -Y in Blender).
eyes = parts[4]
ecol = eyes.data.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
iris = [c * 0.8 for c in P.get("iris", [0.32, 0.2, 0.1])]
centres = {}
for poly in eyes.data.polygons:
    for li in poly.loop_indices:
        vi = eyes.data.loops[li].vertex_index
        co = eyes.data.vertices[vi].co
        side = "l" if co.x > 0 else "r"
        centres.setdefault(side, [])
for side in ("l", "r"):
    pts = [v.co for v in eyes.data.vertices if (v.co.x > 0) == (side == "l")]
    c = sum(pts, Vector()) / max(len(pts), 1)
    centres[side] = c
for poly in eyes.data.polygons:
    for li in poly.loop_indices:
        co = eyes.data.vertices[eyes.data.loops[li].vertex_index].co
        c = centres["l" if co.x > 0 else "r"]
        d = (co - c).normalized()
        fwd = -d.y
        if fwd > 0.93:
            rgb = (0.02, 0.02, 0.02)
        elif fwd > 0.8:
            rgb = tuple(iris)
        else:
            rgb = (0.9, 0.88, 0.85)
        ecol.data[li].color = (*rgb, 1.0)
nt = M_EYES.node_tree
attr = nt.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "Col"
nt.links.new(attr.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])

bpy.data.objects.remove(human, do_unlink=True)

# ---- Join everything into one skinned mesh and reduce triangles for mobile.
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
char = bpy.context.view_layer.objects.active
char.name = "Character"
for m in list(char.modifiers):
    if m.type != 'ARMATURE':
        char.modifiers.remove(m)
ratio = float(P.get("decimate", 0.45))
if ratio < 0.999:
    dec = char.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
    bpy.ops.object.modifier_apply(modifier="Decimate")
# Drop vertex groups that are not bones (helpers, masks).
bone_names = {b.name for b in rig.data.bones}
for g in list(char.vertex_groups):
    if g.name not in bone_names:
        char.vertex_groups.remove(g)
bpy.ops.object.shade_smooth()
tris = sum(len(p.vertices) - 2 for p in char.data.polygons)
print("CHAR_TRIS", tris, "VERTS", len(char.data.vertices))

bpy.ops.object.select_all(action='DESELECT')
char.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                          export_skins=True, export_animations=False, export_apply=False,
                          export_image_format='JPEG', export_jpeg_quality=85,
                          export_yup=True)
print("EXPORTED", OUT, os.path.getsize(OUT))
