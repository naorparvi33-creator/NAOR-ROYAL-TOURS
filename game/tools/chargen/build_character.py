"""Builds a realistic, rigged game character with MakeHuman (MPFB2, CC0) in headless
Blender and exports it as GLB for Godot.

Usage: python3 build_character.py <out.glb> <json params>

Everything is procedural: the body comes from MakeHuman's parametric base mesh, the face
is randomised with MakeHuman's own face targets, and every texture (skin, eyes, hair, cloth)
is painted here with numpy. No photos are used.

Params (all optional):
  seed           int, drives face shape and texture noise
  gender, age, muscle, weight, height, proportions   MakeHuman macros (0..1)
  race           {african, asian, caucasian}
  face           0..1 how far the face departs from the average (default 0.55)
  skin           [r,g,b] sRGB base skin colour
  freckles, blush  0..1
  iris           [r,g,b]
  hair           [r,g,b]
  hair_style     bald | buzz | short | medium | long | ponytail | bun
  hairline       metres, + = receding (older men)
  beard          none | stubble | short | full
  top            tshirt | longsleeve | tank | jacket | hoodie | dress
  shirt          [r,g,b] main top colour (or the t-shirt under a jacket)
  jacket         [r,g,b] jacket / hoodie colour
  bottom         jeans | trousers | shorts | skirt
  pants          [r,g,b] (jeans: tint of the denim texture)
  shoes_style    sneakers | boots | flats
  shoes, sole    [r,g,b]
  hat            none | cap | beanie
  hat_color      [r,g,b]
  glasses        none | clear | sun
  backpack       [r,g,b] or omitted
  lipstick       [r,g,b] or omitted
  tris           triangle budget (default 9000)
"""
import sys, json, math, importlib, os  # noqa
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from setup_mpfb import enable  # noqa: E402

OUT = sys.argv[1]
P = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
NAME = os.path.splitext(os.path.basename(OUT))[0]
MPFB_DATA = "/tmp/mpfb2/src/mpfb/data"
TEX_DIR = MPFB_DATA + "/textures"
GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FABRIC_N = GAME + "/assets/textures/fabric_normal.jpg"
DENIM_A = GAME + "/assets/textures/denim_albedo.jpg"
WORK = "/tmp/chargen/work/" + NAME
os.makedirs(WORK, exist_ok=True)
SEED = int(P.get("seed", abs(hash(NAME)) % 100000))
rng = np.random.default_rng(SEED)
S = 1024                      # skin texture size

pkg = enable()
HumanService = importlib.import_module(pkg + ".services.humanservice").HumanService
TargetService = importlib.import_module(pkg + ".services.targetservice").TargetService

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)


def lin(c):
    """sRGB 0..1 to linear (Blender colour inputs are linear)."""
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


# =====================================================================  body + face
macro = TargetService.get_default_macro_info_dict()
for k in ["gender", "age", "muscle", "weight", "height", "proportions"]:
    if k in P:
        macro[k] = P[k]
if "race" in P:
    macro["race"] = P["race"]
human = HumanService.create_human(macro_detail_dict=macro, feet_on_ground=True)

# Random but plausible face: a few dozen MakeHuman face targets at small weights.
FACE_AXES = {
    "nose": ["nose-trans-up|down", "nose-scale-horiz-incr|decr", "nose-scale-vert-incr|decr",
             "nose-scale-depth-incr|decr", "nose-hump-incr|decr", "nose-point-width-incr|decr",
             "nose-flaring-incr|decr", "nose-curve-convex|concave", "nose-nostrils-width-incr|decr",
             "nose-width1-incr|decr", "nose-base-up|down", "nose-greek-incr|decr"],
    "mouth": ["mouth-scale-horiz-incr|decr", "mouth-lowerlip-volume-incr|decr", "mouth-upperlip-volume-incr|decr",
              "mouth-trans-up|down", "mouth-angles-up|down", "mouth-cupidsbow-incr|decr",
              "mouth-philtrum-volume-incr|decr", "mouth-scale-depth-incr|decr"],
    "chin": ["chin-width-incr|decr", "chin-height-incr|decr", "chin-prominent-incr|decr",
             "chin-bones-incr|decr", "chin-prognathism-incr|decr"],
    "head": ["head-scale-horiz-incr|decr", "head-scale-vert-incr|decr", "head-fat-incr|decr",
             "head-scale-depth-incr|decr", "head-age-incr|decr"],
    "forehead": ["forehead-scale-vert-incr|decr", "forehead-trans-forward|backward", "forehead-temple-incr|decr"],
    "eyebrows": ["eyebrows-trans-up|down", "eyebrows-angle-up|down", "eyebrows-trans-forward|backward"],
    "cheek": ["@-cheek-bones-incr|decr", "@-cheek-volume-incr|decr", "@-cheek-inner-incr|decr"],
    "eyes": ["@-eye-scale-incr|decr", "@-eye-height2-incr|decr", "@-eye-move-up|down",
             "@-eye-move-in|out", "@-eye-bag-incr|decr", "@-eye-corner1-up|down"],
    "ears": ["@-ear-scale-incr|decr", "@-ear-lobe-incr|decr", "@-ear-rot-forward|backward"],
}
FACE_SHAPES = ["head-oval", "head-round", "head-square", "head-rectangular", "head-triangular",
               "head-invertedtriangular", "head-diamond"]
face_amt = float(P.get("face", 0.55))


def target_path(folder, name):
    p = f"{MPFB_DATA}/targets/{folder}/{name}.target.gz"
    return p if os.path.exists(p) else None


loaded = 0
for folder, axes in FACE_AXES.items():
    for ax in axes:
        a, b = ax.split("|")
        stem, pos = a.rsplit("-", 1)
        v = float(rng.normal(0.0, 0.33)) * face_amt
        v = max(-0.85, min(0.85, v))
        if abs(v) < 0.04:
            continue
        name = stem + "-" + (pos if v > 0 else b)
        sides = ["l", "r"] if stem.startswith("@") else [None]
        for s in sides:
            n = name.replace("@", s) if s else name
            path = target_path(folder, n)
            if path:
                TargetService.load_target(human, path, weight=abs(v))
                loaded += 1
shape = FACE_SHAPES[int(rng.integers(len(FACE_SHAPES)))]
TargetService.load_target(human, target_path("head", shape), weight=float(rng.uniform(0.2, 0.6)) * face_amt)
print("FACE_TARGETS", loaded + 1, shape)

rig = HumanService.add_builtin_rig(human, "game_engine")
for m in list(human.modifiers):
    if m.type == 'MASK':
        human.modifiers.remove(m)

# Bake the body shape into the mesh (no shape keys in the game file).
bpy.context.view_layer.objects.active = human
if human.data.shape_keys:
    human.shape_key_add(name="final", from_mix=True)
    final = human.data.shape_keys.key_blocks["final"]
    for v, sk in zip(human.data.vertices, final.data):
        v.co = sk.co
    human.shape_key_clear()

def analyze():
    """(Re)builds the per-vertex lookup tables of the human mesh."""
    global mesh, verts, NV, vg, W, CO, X, Y, Z, is_body, is_eye, is_lash, is_skirt_h, w_head, w_neck, w_ears, w_lips
    mesh = human.data
    verts = mesh.vertices
    NV = len(verts)
    vg = {g.name: g.index for g in human.vertex_groups}
    W = {}
    for v in verts:
        for g in v.groups:
            W.setdefault(g.group, {})[v.index] = g.weight
    CO = np.array([v.co[:] for v in verts], np.float32)
    X, Y, Z = CO[:, 0], CO[:, 1], CO[:, 2]
    is_body = warr("body") > 0.5
    is_eye = (warr("helper-l-eye") + warr("helper-r-eye")) > 0.5
    is_lash = (warr("helper-l-eyelashes-1") + warr("helper-l-eyelashes-2") + warr("helper-r-eyelashes-1") + warr("helper-r-eyelashes-2")) > 0.5
    is_skirt_h = warr("helper-skirt") > 0.5
    w_head = warr("head")
    w_neck = warr("neck_01")
    w_ears = warr("ears")
    w_lips = warr("lips")


def wv(i, name):
    gi = vg.get(name)
    return W.get(gi, {}).get(i, 0.0) if gi is not None else 0.0


def warr(name):
    a = np.zeros(NV, np.float32)
    gi = vg.get(name)
    if gi is not None:
        for i, w in W.get(gi, {}).items():
            a[i] = w
    return a


def wsum_arr(names):
    return sum(warr(n) for n in names)


analyze()

EYE_Z = float(Z[is_eye].mean())
EYE_Y = float(Y[is_eye].mean())
EYE_X = float(np.abs(X[is_eye]).mean())
EYE_FRONT = float(Y[is_eye].min())
head_sel = is_body & (w_head > 0.6)
HEAD_Y = float(Y[head_sel].mean())
HEAD_TOP = float(Z[head_sel].max())
lip_sel = is_body & (w_lips > 0.5)
MOUTH_Z = float(Z[lip_sel].mean())
MOUTH_Y = float(Y[lip_sel].min())
CHIN_Z = float(Z[head_sel & (np.abs(X) < 0.02) & (Y < HEAD_Y - 0.03)].min())
bones = {b.name: b for b in rig.data.bones}
RL = rig.location


def bone_head(n):
    return bones[n].head_local + RL


HIP_Z = bone_head("thigh_l").z
WAIST = HIP_Z + 0.12
KNEE_Z = bone_head("calf_l").z
ANKLE_Z = bone_head("foot_l").z
SHOULDER_Z = bone_head("upperarm_l").z
NECK = bone_head("neck_01")
ARM = {s: (bone_head("upperarm_" + s), bones["upperarm_" + s].tail_local + RL) for s in ("l", "r")}
FORE = {s: (bone_head("lowerarm_" + s), bones["lowerarm_" + s].tail_local + RL) for s in ("l", "r")}
print("LANDMARKS eye_z %.3f head_top %.3f mouth_z %.3f chin %.3f shoulder %.3f hip %.3f knee %.3f" %
      (EYE_Z, HEAD_TOP, MOUTH_Z, CHIN_Z, SHOULDER_Z, HIP_Z, KNEE_Z))

# =====================================================================  outfit rules
hair_style = P.get("hair_style", "short")
beard = P.get("beard", "none")
top = P.get("top", "tshirt")
bottom = P.get("bottom", "jeans")
shoes_style = P.get("shoes_style", "sneakers")
hat = P.get("hat", "none")
if hat != "none" and hair_style in ("long", "bun"):
    hat = "none"
hairline = float(P.get("hairline", 0.0))


def hair_mask(i):
    """Scalp region covered by hair (MakeHuman face looks toward -Y)."""
    if not is_body[i] or w_head[i] < 0.5 or w_ears[i] > 0.2:
        return False
    x, y, z = CO[i]
    front = y < HEAD_Y - 0.035
    if front:
        # Soft M-shaped hairline; receding moves it up at the temples.
        temple = min(abs(x) / 0.05, 1.0)
        return z > EYE_Z + 0.06 + hairline * (0.4 + temple) + (0.008 if abs(x) > 0.03 else 0.0) - 0.004 * (1 - temple)
    back = y > HEAD_Y + 0.02
    if back:
        low = -0.045 if hair_style in ("medium", "long") else -0.028
        return z > EYE_Z + low
    return z > EYE_Z + (0.0 if hair_style in ("medium", "long") else 0.016)


def analyze_parts():
    global is_hair, w_torso, w_ua, w_la, w_leg, w_feet, w_pelvis, hand_names, w_hand
    is_hair = np.array([hair_mask(i) for i in range(NV)])
    w_torso = wsum_arr(TORSO)
    w_ua = wsum_arr(["upperarm_l", "upperarm_r"])
    w_la = wsum_arr(["lowerarm_l", "lowerarm_r"])
    w_leg = wsum_arr(["thigh_l", "thigh_r", "calf_l", "calf_r"])
    w_feet = wsum_arr(["foot_l", "foot_r", "ball_l", "ball_r"])
    w_pelvis = warr("pelvis")
    hand_names = [n for n in vg if n.startswith(("hand_", "index", "middle", "ring", "pinky", "thumb"))]
    w_hand = wsum_arr(hand_names)


TORSO = ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "pelvis"]
analyze_parts()

SLEEVE = {"tank": -0.2, "tshirt": 0.42, "dress": 0.3, "longsleeve": 1.85, "jacket": 1.9, "hoodie": 1.9}[top]
shorts_cut = KNEE_Z + float(P.get("shorts_len", 0.1))
boot_top = ANKLE_Z + 0.13


def region(i):
    """Which garment covers this body vertex (None = bare skin)."""
    if not is_body[i]:
        return None
    x, y, z = CO[i]
    if w_feet[i] > 0.3 or (shoes_style == "boots" and w_leg[i] > 0.3 and z < boot_top):
        return "shoes"
    if w_hand[i] > 0.3:
        return None
    neck = w_neck[i] + w_head[i]
    if neck > 0.45:
        return None
    if w_leg[i] > 0.5 or (w_pelvis[i] > 0.4 and z < WAIST):
        if bottom == "shorts" and z < shorts_cut:
            return None
        if bottom == "skirt" or top == "dress":
            # Only the part that the skirt hides keeps a (short) underlayer.
            return "pants" if z > HIP_Z - 0.06 else None
        return "pants"
    if w_ua[i] + w_la[i] > 0.5:
        side = "l" if x > 0 else "r"
        a, b = ARM[side]
        p = Vector((x, y, z))
        t_arm = (p - a).dot(b - a) / (b - a).length_squared
        if top == "tank":
            return None
        return "shirt" if t_arm < SLEEVE else None
    if w_torso[i] > 0.5:
        if top == "tank" and (w_ua[i] > 0.12 or (z > SHOULDER_Z - 0.06 and abs(x) > 0.07)):
            return None
        if top == "tank" and z > SHOULDER_Z - 0.09 and abs(x) < 0.07 and y < NECK.y:
            return None          # lower neckline in front
        return "shirt"
    return None


# =====================================================================  materials
mats = {}


def mat(name, color, rough=0.8, image=None, normal=None, scale=1.0, metallic=0.0, nstrength=1.0, double=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not double
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    uvmap = None
    if image or normal:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        uvmap = tc.outputs["UV"]
        if scale != 1.0:
            mp = nt.nodes.new("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = (scale, scale, 1.0)
            nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
            uvmap = mp.outputs["Vector"]
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image if isinstance(image, bpy.types.Image) else load_img(image)
        nt.links.new(uvmap, tex.inputs["Vector"])
        if tuple(color) != (1.0, 1.0, 1.0):
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
        nimg.image = load_img(normal)
        nimg.image.colorspace_settings.name = "Non-Color"
        nt.links.new(uvmap, nimg.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = nstrength
        nt.links.new(nimg.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    mats[name] = m
    return m


_imgs = {}


def load_img(path):
    if path not in _imgs:
        img = bpy.data.images.load(path)
        img.name = os.path.splitext(os.path.basename(path))[0]
        _imgs[path] = img
    return _imgs[path]


def save_rgb(arr, path, q=90):
    tmp = "%s.%d.tmp.jpg" % (path, os.getpid())       # atomic: parallel builds share textures
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(tmp, quality=q)
    os.replace(tmp, path)
    return path


def noise(size, cell, seed_off=0, blur=0.0):
    """Smooth value noise 0..1 (cell = feature size in pixels)."""
    r = np.random.default_rng(SEED * 7 + seed_off)
    n = max(2, size // max(1, cell))
    img = Image.fromarray((r.random((n, n)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, np.float32) / 255.0


# ---- shared detail textures (deterministic, identical in every character file)
SHARED = "/tmp/chargen/shared"
os.makedirs(SHARED, exist_ok=True)


def shared_textures():
    r = np.random.default_rng(1234)
    T = 512
    # Skin micro normal: pores + fine creases, tileable by construction (wrap blur).
    h = r.random((T, T)).astype(np.float32)
    def wrap_blur(a, s):
        big = np.tile(a, (3, 3))
        b = np.asarray(Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s)), np.float32) / 255.0
        return b[T:2 * T, T:2 * T]
    pores = wrap_blur((r.random((T, T)) > 0.985).astype(np.float32), 0.8)
    fine = wrap_blur(h, 0.7)
    creases = wrap_blur(r.random((T, T)).astype(np.float32), 2.5)
    height = fine * 0.5 + creases * 0.6 - pores * 2.2
    def to_normal(hh, k):
        gx = (np.roll(hh, -1, 1) - np.roll(hh, 1, 1)) * k
        gy = (np.roll(hh, -1, 0) - np.roll(hh, 1, 0)) * k
        n = np.dstack([-gx, gy, np.ones_like(hh)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        return n * 0.5 + 0.5
    save_rgb(to_normal(height, 1.6), SHARED + "/skin_n.jpg", 92)
    # Hair strands: streaks along V (image Y), with a normal map of the same streaks.
    st = r.random((T // 64, T)).astype(np.float32)
    st = np.asarray(Image.fromarray((st * 255).astype(np.uint8)).resize((T, T), Image.BICUBIC), np.float32) / 255.0
    st2 = r.random((T // 16, T // 2)).astype(np.float32)
    st2 = np.asarray(Image.fromarray((st2 * 255).astype(np.uint8)).resize((T, T), Image.BICUBIC), np.float32) / 255.0
    strands = st * 0.65 + st2 * 0.35
    alb = 0.62 + strands * 0.55
    save_rgb(np.dstack([alb, alb, alb]), SHARED + "/hair.jpg", 90)
    save_rgb(to_normal(strands, 3.0), SHARED + "/hair_n.jpg", 90)
    # Knit / cotton albedo: soft heather noise with a fine weave.
    yy, xx = np.mgrid[0:T, 0:T]
    weave = (np.sin(xx * math.pi / 2.0) * np.sin(yy * math.pi / 2.0)) * 0.025
    heather = wrap_blur(r.random((T, T)).astype(np.float32), 1.0) * 0.1 + wrap_blur(r.random((T, T)).astype(np.float32), 6) * 0.08
    k = 0.86 + heather + weave
    save_rgb(np.dstack([k, k, k]), SHARED + "/knit.jpg", 90)


if not os.path.exists(SHARED + "/knit.jpg"):
    shared_textures()

# =====================================================================  UV-space painting
uv_layer = mesh.uv_layers.active.data
polys = [p for p in mesh.polygons]
P_VERTS = [list(p.vertices) for p in polys]
P_CENT = np.array([CO[pv].mean(axis=0) for pv in P_VERTS], np.float32)
P_BODY = np.array([all(is_body[i] for i in pv) for pv in P_VERTS])
P_UV = [[(uv_layer[li].uv.x * S, (1.0 - uv_layer[li].uv.y) * S) for li in p.loop_indices] for p in polys]
P_HEAD = np.array([w_head[pv].mean() for pv in P_VERTS], np.float32)


def raster(values, blur=1.5, size=S):
    """values: per-polygon 0..1 (only body polygons). Returns size x size float mask."""
    layer = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(layer)
    sc = size / S
    for pi in np.nonzero((values > 0.003) & P_BODY)[0]:
        d.polygon([(u * sc, v * sc) for u, v in P_UV[pi]], fill=int(min(values[pi], 1.0) * 255))
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(layer, np.float32) / 255.0


def gauss3(c, centre, radius):
    d = np.linalg.norm((c - np.array(centre, np.float32)) / np.array(radius, np.float32), axis=1)
    return np.exp(-d * d)


def mpfb_mask(n):
    return np.asarray(Image.open(f"{TEX_DIR}/mpfb_{n}.jpg").convert("L").resize((S, S), Image.BILINEAR), np.float32) / 255.0


skin_rgb = np.array(P.get("skin", [0.78, 0.6, 0.48]), np.float32)
hair_rgb = np.array(P.get("hair", [0.1, 0.075, 0.06]), np.float32)
male = float(P.get("gender", 0.5)) > 0.5
age = float(P.get("age", 0.5))
cx, cy, cz = P_CENT[:, 0], P_CENT[:, 1], P_CENT[:, 2]
front = cy < HEAD_Y - 0.02


def paint_skin_base():
    col = np.ones((S, S, 3), np.float32) * skin_rgb
    # Mottling: low-frequency redness / tone variation and fine grain.
    blotch = noise(S, 48, 1)
    tone = noise(S, 160, 2)
    grain = noise(S, 2, 3, 0.6)
    red = np.array([1.04, 0.97, 0.96], np.float32)
    col *= (0.95 + tone[..., None] * 0.08)
    col = col * (1 + (blotch[..., None] - 0.5) * 0.08 * (red - 1) * 6)
    col *= (0.975 + grain[..., None] * 0.05)
    # Pores read as tiny dark dots.
    pores = (np.random.default_rng(SEED + 9).random((S, S)) > 0.992).astype(np.float32)
    pores = np.asarray(Image.fromarray((pores * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    col *= 1 - pores[..., None] * 0.25
    return col


col = paint_skin_base()
face = mpfb_mask("face")[..., None]
col = col * (1 - face * 0.1) + col * np.array([1.05, 0.97, 0.95]) * face * 0.1     # warmer face
# Lips: darker, redder; optional lipstick.
lips = mpfb_mask("lips")[..., None]
lip_col = skin_rgb * np.array([0.86, 0.6, 0.6])
if "lipstick" in P:
    lip_col = np.array(P["lipstick"], np.float32)
col = col * (1 - lips * 0.55) + lip_col * lips * 0.55
lids = mpfb_mask("eyelids")[..., None]
col *= 1 - lids * 0.14
for n in ["fingernails", "toenails"]:
    m = mpfb_mask(n)[..., None]
    col = col * (1 - m * 0.55) + np.array([0.93, 0.8, 0.76]) * m * 0.55
ears = mpfb_mask("ears")[..., None]
col = col * (1 - ears * 0.06) + col * np.array([1.05, 0.93, 0.92]) * ears * 0.06

face_poly = (P_HEAD > 0.5).astype(np.float32)
# Cheek blush and a slightly red nose tip.
blush = float(P.get("blush", 0.35 if not male else 0.2))
bl = sum(gauss3(P_CENT, (s * (EYE_X + 0.012), EYE_Y - 0.01, EYE_Z - 0.045), (0.028, 0.03, 0.022)) for s in (1, -1))
bl = bl * face_poly * front
bmask = raster(bl, 6)[..., None] * blush
col = col * (1 - bmask * 0.35) + col * np.array([1.1, 0.82, 0.82]) * bmask * 0.35
nose = gauss3(P_CENT, (0, MOUTH_Y - 0.01, MOUTH_Z + 0.03), (0.014, 0.02, 0.012)) * face_poly
nmask = raster(nose, 4)[..., None]
col = col * (1 - nmask * 0.12) + col * np.array([1.08, 0.9, 0.9]) * nmask * 0.12
# Under-eye shadow (more with age).
ue = sum(gauss3(P_CENT, (s * EYE_X, EYE_Y - 0.008, EYE_Z - 0.017), (0.016, 0.03, 0.008)) for s in (1, -1)) * face_poly
umask = raster(ue, 3)[..., None] * (0.25 + age * 0.4)
col = col * (1 - umask * 0.25) + col * np.array([0.86, 0.8, 0.86]) * umask * 0.25
# Freckles over nose and cheeks.
fr = float(P.get("freckles", 0.0))
if fr > 0:
    zone = gauss3(P_CENT, (0, MOUTH_Y, EYE_Z - 0.03), (0.06, 0.06, 0.035)) * face_poly * front
    zmask = raster(zone, 8)
    dots = (np.random.default_rng(SEED + 5).random((S, S)) > 0.985).astype(np.float32)
    dots = np.asarray(Image.fromarray((dots * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1)), np.float32) / 255.0
    f = np.clip(dots * 2.0, 0, 1) * zmask * fr
    col = col * (1 - f[..., None] * 0.5) + col * np.array([0.72, 0.55, 0.42]) * f[..., None] * 0.5


def hair_paint(maskv, density, strength, blur=1.0, seed_off=0, cell=1, streak=False, erode=0):
    """Paints hair-coloured speckles (stubble, buzz cut) or short strokes (brows) into the skin."""
    global col
    m = raster(maskv, 0 if erode else blur)
    if erode:
        # Shrink first so the paint stays under the hair shell, then soften.
        im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(erode * 2 + 1))
        m = np.asarray(im.filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255.0
    sp = np.random.default_rng(SEED + 31 + seed_off).random((S, S)).astype(np.float32)
    if streak:
        sp = np.asarray(Image.fromarray((sp[:, :S // 6] * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR), np.float32) / 255.0
        sp = np.clip((sp - 0.5) * 1.8 + 0.5, 0, 1)
    if cell > 1:
        sp = np.asarray(Image.fromarray((sp * 255).astype(np.uint8)).resize((S // cell, S // cell)).resize((S, S), Image.NEAREST), np.float32) / 255.0
    dots = np.clip((sp - (1 - density)) / max(density, 1e-3), 0, 1)
    a = (m * (0.35 + 0.65 * dots) * strength)[..., None]
    col = col * (1 - a) + hair_rgb * 0.85 * a


# Eyebrows: arched band above each eye, thicker towards the nose.
brow = np.zeros(len(polys), np.float32)
for s in (1, -1):
    dx = (cx * s - EYE_X)
    arch = 0.0165 - (dx / 0.03) ** 2 * 0.006
    dz = cz - EYE_Z
    width = (0.006 - dx * 0.06) * (1.0 if male else 0.72)
    inside = (dx > -0.022) & (dx < 0.024) & (np.abs(dz - arch) < np.maximum(width, 0.0025)) & (cx * s > 0.008) & (cy < EYE_Y + 0.012)
    brow += inside * (1.0 - np.clip((dx + 0.02) / 0.06, 0, 0.6))
brow *= face_poly
brow_dark = float(P.get("brows", 0.82 if male else 0.68))
hair_paint(brow, 0.85, brow_dark, 1.6, 1, streak=True)

# Stubble / beard shadow.
beard_poly = (face_poly > 0) & (cz < MOUTH_Z + 0.006) & (cz > CHIN_Z - 0.035) & (cy < HEAD_Y + 0.025)
beard_poly &= ~((np.abs(cx) < 0.03) & (np.abs(cz - MOUTH_Z) < 0.008) & front)        # keep the lips clear
cheek_line = MOUTH_Z + 0.02 - np.abs(cx) * 0.25
beard_poly |= (face_poly > 0) & (cz < cheek_line) & (cz > MOUTH_Z - 0.01) & (np.abs(cx) > 0.035) & (cy < HEAD_Y + 0.02)
moustache = (face_poly > 0) & front & (np.abs(cx) < 0.028) & (cz > MOUTH_Z + 0.004) & (cz < MOUTH_Z + 0.018)
neck_beard = np.array([w_neck[pv].mean() > 0.4 for pv in P_VERTS]) & (cz > CHIN_Z - 0.05) & (cy < NECK.y)
if beard != "none":
    bp = (beard_poly | moustache | (neck_beard if beard != "stubble" else False)).astype(np.float32)
    dens = {"stubble": 0.55, "short": 0.85, "full": 0.95}[beard]
    hair_paint(bp, dens, {"stubble": 0.6, "short": 0.88, "full": 0.97}[beard], 1.6 if beard == "stubble" else 2.4, 2, streak=beard == "full")
elif male:
    bp = (beard_poly | moustache).astype(np.float32)
    hair_paint(bp, 0.4, 0.18, 2.0, 2)          # clean-shaven shadow

# Scalp under hair: hides any gap at the hairline and makes buzz cuts.
if hair_style != "bald":
    scalp = np.array([all(is_hair[i] for i in pv) for pv in P_VERTS]).astype(np.float32)
    if hair_style == "buzz":
        hair_paint(scalp, 0.65, 0.92, 1.2, 3)
    else:
        hair_paint(scalp, 0.8, 0.9, 3.0, 3, erode=5)

# Older people: faint age spots and a little less saturation.
if age > 0.65:
    g = col.mean(axis=2, keepdims=True)
    col = col * 0.9 + g * 0.1
    sp = (np.random.default_rng(SEED + 77).random((S, S)) > 0.9985).astype(np.float32)
    sp = np.asarray(Image.fromarray((sp * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.0)), np.float32)[..., None] / 255.0
    col = col * (1 - sp * 0.4) + col * np.array([0.8, 0.68, 0.58]) * sp * 0.4

SKIN_IMG = bpy.data.images.new("skin", S, S, alpha=False)
M_SKIN = mat("skin", (1.0, 1.0, 1.0), 0.52, image=SKIN_IMG, normal=SHARED + "/skin_n.jpg", scale=5.0, nstrength=0.35)
# Note: the mapping scale also tiles the albedo; undo it for the albedo by linking UV directly.
nt = M_SKIN.node_tree
alb_node = [n for n in nt.nodes if n.type == 'TEX_IMAGE' and n.image == SKIN_IMG][0]
tc = [n for n in nt.nodes if n.type == 'TEX_COORD'][0]
nt.links.new(tc.outputs["UV"], alb_node.inputs["Vector"])

# =====================================================================  clothing texture
# All garments share MakeHuman's body UVs, so one per-character texture holds every garment's
# colour, pattern, seams and wear. It is painted per pixel from a baked position map.
shirt_rgb = np.array(P.get("shirt", [0.85, 0.85, 0.83]), np.float32)
jacket_rgb = np.array(P.get("jacket", [0.15, 0.17, 0.2]), np.float32)
pants_rgb = np.array(P.get("pants", [0.33, 0.45, 0.62] if bottom == "jeans" else [0.25, 0.25, 0.28]), np.float32)
pattern = P.get("pattern", "plain")
stripe_rgb = np.array(P.get("stripe", [0.95, 0.95, 0.93]), np.float32)


def bake_positions(objs, size):
    """Bakes the surface position of the given (garment) objects into their UV layout.
    Returns (positions HxWx3, coverage HxW)."""
    tm = bpy.data.materials.new("_posbake")
    tm.use_nodes = True
    img = bpy.data.images.new("_pos", size, size, alpha=True, float_buffer=True)
    node = tm.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    tm.node_tree.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 1
    sc.cycles.device = 'CPU'
    first = True
    for o in objs:
        tmp = o.copy()
        tmp.data = o.data.copy()
        bpy.context.collection.objects.link(tmp)
        for m in list(tmp.modifiers):
            tmp.modifiers.remove(m)
        tmp.data.materials.clear()
        tmp.data.materials.append(tm)
        bpy.ops.object.select_all(action='DESELECT')
        tmp.select_set(True)
        bpy.context.view_layer.objects.active = tmp
        bpy.ops.object.bake(type='POSITION', margin=0, use_clear=first)   # exact coverage; bled later
        first = False
        me = tmp.data
        bpy.data.objects.remove(tmp, do_unlink=True)
        bpy.data.meshes.remove(me)
    px = np.array(img.pixels[:], np.float32).reshape(size, size, 4)[::-1].copy()
    bpy.data.images.remove(img)
    bpy.data.materials.remove(tm)
    cov = (np.abs(px[..., :3]).sum(axis=2) > 1e-6).astype(np.float32)
    return px[..., :3], cov


def tile(path, scale, size):
    """Repeats a texture `scale` times over the UV square, resampled to size."""
    t = np.asarray(Image.open(path).convert("RGB"), np.float32) / 255.0
    th, tw = t.shape[:2]
    yy, xx = np.mgrid[0:size, 0:size]
    return t[(yy * scale * th // size) % th, (xx * scale * tw // size) % tw]


def paint_cloth(top_objs, pants_objs):
    C = S
    pos, m_top = bake_positions(top_objs, C)
    pos_p, m_pants = bake_positions(pants_objs, C) if pants_objs else (pos, np.zeros((C, C), np.float32))
    px, py, pz = pos[..., 0], pos[..., 1], pos[..., 2]
    knit = tile(SHARED + "/knit.jpg", 6, C)
    outer_rgb = jacket_rgb if top in ("jacket", "hoodie") else shirt_rgb
    col = np.ones((C, C, 3), np.float32) * outer_rgb        # default: hood, collar etc.
    front_ = py < NECK.y
    # ---- inner shirt (also what shows in an open jacket)
    shirt = np.ones((C, C, 3), np.float32) * shirt_rgb
    if pattern == "stripes":
        st = (np.sin(pz * math.pi * 2 / 0.045) > 0.25).astype(np.float32)
        shirt = shirt * (1 - st[..., None]) + stripe_rgb * st[..., None]
    elif pattern == "plaid":
        a = (np.sin(pz * math.pi * 2 / 0.07) > 0.3).astype(np.float32)
        b = (np.sin(px * math.pi * 2 / 0.07 + py * 20) > 0.3).astype(np.float32)
        f = np.clip(a * 0.5 + b * 0.5, 0, 1)[..., None]
        shirt = shirt * (1 - f * 0.55) + stripe_rgb * f * 0.55
        thin = ((np.abs(np.sin(pz * math.pi * 2 / 0.07 + 1.2)) < 0.06) | (np.abs(np.sin(px * math.pi * 2 / 0.07 + 1.2)) < 0.06))
        shirt[thin] = shirt[thin] * 0.6 + np.array([0.9, 0.85, 0.75]) * 0.4
    elif pattern == "print":
        # A simple geometric chest graphic: ring and bar (no text, no logos).
        cz0 = SHOULDER_Z - 0.13
        d = np.hypot(px, pz - cz0)
        ring = (np.abs(d - 0.045) < 0.009) & front_
        bar = (np.abs(pz - cz0) < 0.008) & (np.abs(px) < 0.07) & front_
        g = (ring | bar).astype(np.float32)[..., None]
        shirt = shirt * (1 - g) + stripe_rgb * g
    elif pattern == "raglan":
        arm = (np.abs(px) > 0.17 - np.clip(pz - (SHOULDER_Z - 0.1), 0, 0.2) * 0.6)
        shirt[arm] = stripe_rgb
    # ---- outer layer
    if top == "jacket":
        jk = np.ones((C, C, 3), np.float32) * jacket_rgb
        # Open front: the shirt shows in a V that narrows toward the waist.
        half = 0.045 + np.clip(pz - (SHOULDER_Z - 0.25), 0, 1) * 0.12
        opening = (np.abs(px) < half) & front_ & (pz < SHOULDER_Z + 0.02) & (pz > HIP_Z - 0.1)
        edge = (np.abs(np.abs(px) - half) < 0.006) & front_ & (pz < SHOULDER_Z + 0.02)
        top_col = np.where(opening[..., None], shirt, jk)
        top_col[edge] *= 0.6
        cuff = (np.abs(px) > 0.5) & (np.abs(px) < 0.56)
        top_col[cuff] *= 0.8
        for sx in (1, -1):
            pk = front_ & (np.abs(px - sx * 0.1) < 0.035) & (np.abs(pz - (SHOULDER_Z - 0.13)) < 0.004)
            top_col[pk] *= 0.65
    elif top == "hoodie":
        top_col = np.ones((C, C, 3), np.float32) * jacket_rgb
        pocket = front_ & (np.abs(px) < 0.13 - (pz - (HIP_Z + 0.06)) * 0.4) & (pz > HIP_Z + 0.02) & (pz < HIP_Z + 0.17)
        inner = front_ & (np.abs(px) < 0.12 - (pz - (HIP_Z + 0.06)) * 0.4) & (pz > HIP_Z + 0.03) & (pz < HIP_Z + 0.16)
        top_col[pocket] *= 0.93
        top_col[pocket & ~inner] *= 0.7
        strings = front_ & (np.abs(np.abs(px) - 0.035) < 0.004) & (pz > SHOULDER_Z - 0.14) & (pz < SHOULDER_Z + 0.02)
        top_col[strings] = np.array([0.9, 0.9, 0.88])
        top_col[pz < HIP_Z - 0.01] *= 0.85
        top_col[np.abs(px) > 0.52] *= 0.85
    else:
        top_col = shirt
        # Ribbed neckline.
        band = (np.hypot(px, (py - NECK.y) * 1.3) < 0.095) & (pz > SHOULDER_Z - 0.03) & (pz < SHOULDER_Z + 0.06)
        top_col[band] *= 0.9
    top_col = top_col * (0.9 + knit * 0.12)
    pit = np.clip(1 - np.abs(np.abs(px) - 0.17) / 0.05, 0, 1) * np.clip(1 - np.abs(pz - (SHOULDER_Z - 0.1)) / 0.08, 0, 1)
    top_col *= (1 - pit * 0.2)[..., None]
    # ---- trousers (positions of the trouser shell)
    px, py, pz = pos_p[..., 0], pos_p[..., 1], pos_p[..., 2]
    front_ = py < NECK.y
    if bottom == "jeans":
        den = tile(DENIM_A, 7, C)
        den = den / np.maximum(den.mean(axis=(0, 1), keepdims=True), 1e-3)
        pc = np.ones((C, C, 3), np.float32) * pants_rgb * den
        # Wear: lighter fronts of the thighs and knees, darker creases behind the knees.
        thigh = np.clip(1 - np.abs(pz - (HIP_Z - 0.18)) / 0.15, 0, 1) * front_
        knee = np.clip(1 - np.abs(pz - KNEE_Z) / 0.06, 0, 1)
        fade = (thigh * 0.22 + knee * 0.12 * front_)[..., None] * noise(C, 24, 41)[..., None]
        pc = pc * (1 - fade) + np.minimum(pc * 1.9, 1.0) * fade
        pc *= (1 - (knee * (~front_) * 0.25))[..., None]
        pc[(pz > WAIST - 0.045) & (pz < WAIST - 0.005)] *= 0.88
        if P.get("belt"):
            pc[(pz > WAIST - 0.04) & (pz < WAIST - 0.012)] = np.array(P["belt"], np.float32)
        stitch = np.array([0.72, 0.55, 0.3])
        for sx in (1, -1):
            pk = (~front_) & (np.abs(px - sx * 0.075) < 0.05) & (pz > HIP_Z - 0.1) & (pz < HIP_Z + 0.02)
            ol = pk & ~((~front_) & (np.abs(px - sx * 0.075) < 0.045) & (pz > HIP_Z - 0.095) & (pz < HIP_Z + 0.015))
            pc[ol] = pc[ol] * 0.5 + stitch * 0.5
            fp = front_ & (np.abs(np.hypot(px - sx * 0.14, pz - WAIST) - 0.08) < 0.003) & (pz < WAIST) & (np.abs(px) < 0.17)
            pc[fp] = pc[fp] * 0.5 + stitch * 0.5
        pc[pz < ANKLE_Z + 0.05] *= 0.85
    else:
        pc = np.ones((C, C, 3), np.float32) * pants_rgb * (0.9 + knit * 0.12)
        pc[(pz > WAIST - 0.04) & (pz < WAIST - 0.005)] *= 0.85
        if P.get("belt"):
            pc[(pz > WAIST - 0.035) & (pz < WAIST - 0.012)] = np.array(P["belt"], np.float32)
        for sx in (1, -1):
            cr = front_ & (np.abs(px - sx * 0.095) < 0.003) & (pz < HIP_Z - 0.05)
            pc[cr] *= 1.08
    col = col * (1 - m_pants[..., None]) + pc * m_pants[..., None]
    col = col * (1 - m_top[..., None]) + top_col * m_top[..., None]
    # Bleed the painted islands outward so mipmaps and bilinear filtering never pick up
    # unrelated colours at the UV seams.
    cov = np.clip(m_top + m_pants, 0, 1)
    for _ in range(4):
        num = np.stack([np.asarray(Image.fromarray(((col[..., c] * cov) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(3)), np.float32) for c in range(3)], axis=2)
        den = np.asarray(Image.fromarray((cov * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(3)), np.float32)[..., None]
        fill = (cov < 0.5) & (den[..., 0] > 0.5)
        col[fill] = num[fill] / den[fill]
        cov = np.maximum(cov, fill.astype(np.float32))
    path = f"{WORK}/cloth.jpg"
    save_rgb(col, path, 90)
    return path


# =====================================================================  mobile triangle budget
# Decimate the closed base mesh *before* cutting garments (open edges would erode), in two
# passes so the face keeps more detail than the body. Only vertices in the given group collapse.
budget = int(P.get("tris", 9000))


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def decimate(o, ratio, group=None, invert=False):
    if ratio >= 0.999:
        return
    bpy.context.view_layer.objects.active = o
    dec = o.modifiers.new("Decimate", 'DECIMATE')
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    if group:
        dec.vertex_group = group
        dec.invert_vertex_group = invert
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
        bpy.ops.object.modifier_apply(modifier="Decimate")


def decimate_to(o, target, group=None, invert=False):
    """Decimates to about `target` triangles in total (searching the ratio on copies)."""
    n = tri_count(o)
    if target >= n:
        return
    r = target / n
    for _ in range(6):
        tmp = o.copy()
        tmp.data = o.data.copy()
        bpy.context.collection.objects.link(tmp)
        decimate(tmp, r, group, invert)
        got = tri_count(tmp)
        me = tmp.data
        bpy.data.objects.remove(tmp, do_unlink=True)
        bpy.data.meshes.remove(me)
        if abs(got - target) < target * 0.02:
            break
        # Only part of the mesh can collapse: scale the reduction, not the total.
        r = max(0.005, min(1.0, r * (1.0 + (target - got) / max(n - got, 1))))
    decimate(o, r, group, invert)


def body_poly_count(sel):
    return sum(len(p.vertices) - 2 for p in mesh.polygons if all(sel[i] for i in p.vertices))


face_sel = is_body & (w_head > 0.3)
rest_sel = is_body & ~face_sel
g_rest = human.vertex_groups.new(name="_dec_rest")
g_face = human.vertex_groups.new(name="_dec_face")
g_rest.add([int(i) for i in np.nonzero(rest_sel)[0]], 1.0, 'REPLACE')
g_face.add([int(i) for i in np.nonzero(face_sel)[0]], 1.0, 'REPLACE')
body_target = int(budget * float(P.get("body_share", 0.78))) - 600
face_t = int(body_target * 0.36)
rest_n, face_n = body_poly_count(rest_sel), body_poly_count(face_sel)
total = tri_count(human)
decimate_to(human, total - rest_n + (body_target - face_t), "_dec_rest")
decimate_to(human, tri_count(human) - face_n + face_t, "_dec_face")
human.vertex_groups.remove(human.vertex_groups["_dec_rest"])
human.vertex_groups.remove(human.vertex_groups["_dec_face"])
analyze()
analyze_parts()
print("BODY_TRIS", rest_n + face_n, "->", body_poly_count(is_body), "(face %d -> %d)" % (face_n, body_poly_count(is_body & (w_head > 0.3))))
regions = [region(i) for i in range(NV)]
# The cloth texture is painted from positions baked on the *decimated* surface, so seams and
# stripes stay straight on the low-poly garments (the UV mapping is linear per triangle).

# =====================================================================  garments
KNIT = SHARED + "/knit.jpg"
CLOTH_IMG = bpy.data.images.new("cloth_tmp", 8, 8, alpha=False)     # painted once the garments exist
M_CLOTH = mat("cloth", (1.0, 1.0, 1.0), 0.88, image=CLOTH_IMG, normal=FABRIC_N, scale=8.0, nstrength=0.7)
_n = M_CLOTH.node_tree
_alb = [n for n in _n.nodes if n.type == 'TEX_IMAGE' and n.image == CLOTH_IMG][0]
_n.links.new([n for n in _n.nodes if n.type == 'TEX_COORD'][0].outputs["UV"], _alb.inputs["Vector"])
M_SHIRT = M_TOP = M_PANTS = M_CLOTH
skirt_rgb = P.get("skirt", list(shirt_rgb) if top == "dress" else list(pants_rgb))
M_SKIRT = mat("skirt", lin(skirt_rgb), 0.85, image=KNIT, normal=FABRIC_N, scale=6.0, double=True)
shoe_rgb = P.get("shoes", [0.92, 0.92, 0.9])
M_SHOES = mat("shoes", lin(shoe_rgb), 0.45 if shoes_style != "sneakers" else 0.7,
              normal=FABRIC_N if shoes_style == "sneakers" else None, scale=10.0)
M_SOLE = mat("sole", lin(P.get("sole", [0.95, 0.95, 0.93] if shoes_style == "sneakers" else [0.08, 0.07, 0.06])), 0.8)
HAIR_A = SHARED + "/hair.jpg"
M_HAIR = mat("hair", lin(hair_rgb), 0.55, image=HAIR_A, normal=SHARED + "/hair_n.jpg", double=True, nstrength=0.8)
M_LASH = mat("lashes", lin(hair_rgb * (0.45 if male else 0.3)), 0.7, double=True)

INFLATE = {"Shirt": 0.017, "Top": 0.024 if top == "jacket" else 0.02, "Pants": 0.011}
SMOOTH = {"Shirt": 4, "Top": 8, "Pants": 8, "Shoes": 18, "Hair": 3}


def boundary_smooth(bm, iters=6):
    """Straightens the zig-zag edges left by the per-vertex region cut."""
    bverts = [v for v in bm.verts if v.is_boundary]
    for _ in range(iters):
        new = {}
        for v in bverts:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2:
                new[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, c in new.items():
            v.co = c


def add_rim(bm, under):
    """Folds the open edges back to the body so cuffs/hairlines look thick, not paper thin.
    under: inflated vertex -> the point on the body surface it was pushed out from."""
    edges = [e for e in bm.edges if e.is_boundary]
    if not edges:
        return
    uvl = bm.loops.layers.uv.active
    src = {}
    for e in edges:
        for v in e.verts:
            if v in under:
                uv = v.link_loops[0][uvl].uv.copy() if (uvl and v.link_loops) else None
                src[tuple(round(c, 6) for c in v.co)] = (under[v], uv)
    res = bmesh.ops.extrude_edge_only(bm, edges=edges)
    # extrude_edge_only leaves the new verts in place: find their source by position, and give
    # the fold the UVs of the edge it comes from (so it samples the garment's own colour).
    newv = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in newv:
        t = src.get(tuple(round(c, 6) for c in v.co))
        if t is not None:
            if uvl and t[1] is not None:
                for lp in v.link_loops:
                    lp[uvl].uv = t[1]
            v.co = t[0]
    if uvl:
        for f in [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
            for lp in f.loops:
                if lp.vert not in newv and lp.vert.link_loops:
                    lp[uvl].uv = lp.vert.link_loops[0][uvl].uv.copy() if lp.vert.link_loops[0].face is not f else lp[uvl].uv


def build_part(name, keep_face, inflate, material, smooth=None, rim=True, bsmooth=6, src=None):
    src = src or human
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if not keep_face(f)]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    # Smoothing removes anatomy (muscles, toes) so garments read as fabric / shoes.
    for _ in range(SMOOTH.get(name, 0) if smooth is None else smooth):
        # Open edges are excluded: smoothing them would pull hems and cuffs up the limb.
        bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    if bsmooth:
        boundary_smooth(bm, bsmooth)
    bm.normal_update()
    if inflate:
        under = {}
        for v in bm.verts:
            under[v] = v.co + v.normal * (inflate * 0.15)
            v.co += v.normal * inflate
        if rim:
            add_rim(bm, under)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def covered_by(names, strict=False):
    names = set(names) if isinstance(names, (list, tuple, set)) else {names}

    def keep(f):
        rs = [regions[v.index] for v in f.verts]
        return all(r in names for r in rs) if strict else any(r in names for r in rs)
    return keep


parts = []
outer = None
if top in ("jacket", "hoodie"):
    # The thick top also hangs a bit lower over the hips.
    for i in range(NV):
        if regions[i] == "pants" and is_body[i] and w_leg[i] < 0.5 and CO[i][2] > HIP_Z - (0.07 if top == "jacket" else 0.04):
            regions[i] = "top_low"
    outer = build_part("Top", covered_by(["shirt", "top_low"]), INFLATE["Top"], M_TOP)
    parts.append(outer)
else:
    parts.append(build_part("Shirt", covered_by("shirt"), INFLATE["Shirt"], M_SHIRT))
# The trousers take only faces that are entirely theirs: no face is shared with the top, so
# the two never sample the same texels of the clothing texture (the top hangs over the seam).
parts.append(build_part("Pants", covered_by("pants", strict=True), INFLATE["Pants"], M_PANTS))
for i in range(NV):
    if regions[i] == "top_low":
        regions[i] = "pants"

# Hoodie: the hood lies as a thick roll around the back of the neck.
if top == "hoodie":
    def hood_keep(f):
        for v in f.verts:
            i = v.index
            if not is_body[i]:
                return False
        c = sum((v.co for v in f.verts), Vector()) / len(f.verts)
        neckish = (w_neck[[v.index for v in f.verts]].mean() > 0.2) or (c.z > SHOULDER_Z - 0.06 and c.z < NECK.z + 0.06)
        return neckish and c.y > NECK.y - 0.035 and c.z < NECK.z + 0.075 and c.z > SHOULDER_Z - 0.1 and abs(c.x) < 0.11 and w_head[[v.index for v in f.verts]].mean() < 0.3
    hood = build_part("Hood", hood_keep, 0.03, M_TOP, smooth=14, bsmooth=10, rim=False)
    parts.append(hood)

# Paint the clothing texture from the final (smoothed, decimated) garment surfaces, so
# stripes, seams and the open jacket front stay straight on the low-poly shells.
_top_objs = [o for o in parts if o.name.split(".")[0] in ("Top", "Shirt", "Hood")]
_pants_objs = [o for o in parts if o.name.split(".")[0] == "Pants"]
_cloth_img = load_img(paint_cloth(_top_objs, _pants_objs))
_alb.image = _cloth_img
bpy.data.images.remove(CLOTH_IMG)

# Skirt / dress: MakeHuman's skirt helper, re-weighted so it does not split with the legs.
if bottom == "skirt" or top == "dress":
    sk_len = float(P.get("skirt_len", 0.0))
    skirt = build_part("Skirt", lambda f: all(is_skirt_h[v.index] for v in f.verts), 0.004, M_SKIRT, smooth=2, rim=False, bsmooth=0)
    sm = skirt.data
    zs_ = [v.co.z for v in sm.vertices]
    ztop, zbot = max(zs_), min(zs_)
    for v in sm.vertices:
        t = (ztop - v.co.z) / max(ztop - zbot, 1e-3)
        v.co.z -= t * sk_len
        if t > 0.05:
            v.co.x *= 1.0 + t * 0.12
            v.co.y = (v.co.y - HEAD_Y * 0) * (1.0 + t * 0.08)
    gi = {g.name: g.index for g in skirt.vertex_groups}
    for v in sm.vertices:
        t = (ztop - v.co.z) / max(ztop - zbot, 1e-3)
        for g in list(v.groups):
            skirt.vertex_groups[g.group].remove([v.index])
        side = "thigh_l" if v.co.x > 0 else "thigh_r"
        lean = min(abs(v.co.x) / 0.12, 1.0)
        wt = 0.45 * t * lean
        skirt.vertex_groups[gi["pelvis"]].add([v.index], 1.0 - wt, 'REPLACE')
        if wt > 0.001:
            skirt.vertex_groups[gi[side]].add([v.index], wt, 'REPLACE')
    parts.append(skirt)

# Shoes: convex hull per foot (smooth, toeless), sole in a second material.
shoes = build_part("Shoes", covered_by("shoes"), 0.0, M_SHOES, rim=False, bsmooth=0)
bm = bmesh.new()
bm.from_mesh(shoes.data)
for side in (1, -1):
    vs = [v for v in bm.verts if v.co.x * side > 0]
    old_faces = list({f for v in vs for f in v.link_faces})
    res = bmesh.ops.convex_hull(bm, input=vs)
    hull_faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    bmesh.ops.delete(bm, geom=[f for f in old_faces if f.is_valid and f not in hull_faces], context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
# Subdivide once so the sole line is clean, then round the hull a little.
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.normal_update()
for v in bm.verts:
    v.co += v.normal * (0.008 if shoes_style != "flats" else 0.004)
    v.co.z = max(v.co.z, -0.005)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
SOLE_H = {"sneakers": 0.03, "boots": 0.028, "flats": 0.012}[shoes_style]
bm.to_mesh(shoes.data)
bm.free()
shoes.data.materials.append(M_SOLE)
for poly in shoes.data.polygons:
    c = sum((shoes.data.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
    if c.z < SOLE_H:
        poly.material_index = 1
parts.append(shoes)

# =====================================================================  hair
hair_obj = None


def head_radius_at(z, band=0.012):
    """Polar profile of the head (incl. hair-cap region) at height z: 36 angle bins."""
    sel = is_body & (w_head > 0.4) & (w_ears < 0.1) & (np.abs(Z - z) < band)
    ang = np.arctan2(X[sel], Y[sel] - HEAD_Y)
    rad = np.hypot(X[sel], Y[sel] - HEAD_Y)
    prof = np.zeros(36, np.float32)
    bins = ((ang + math.pi) / (2 * math.pi) * 36).astype(int) % 36
    for b, r in zip(bins, rad):
        prof[b] = max(prof[b], r)
    for _ in range(3):            # fill empty bins
        for b in range(36):
            if prof[b] == 0:
                prof[b] = max(prof[(b - 1) % 36], prof[(b + 1) % 36])
    return prof


def prof_at(prof, a):
    f = (a + math.pi) / (2 * math.pi) * 36 - 0.5
    i0 = int(math.floor(f)) % 36
    t = f - math.floor(f)
    return prof[i0] * (1 - t) + prof[(i0 + 1) % 36] * t


def set_uv_crown(obj):
    """Spherical UVs radiating from the crown so the strand texture flows downward."""
    me = obj.data
    uv = me.uv_layers.active.data
    cz0 = HEAD_TOP
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            a = math.atan2(co.x, co.y - HEAD_Y)
            u = (a / (2 * math.pi) + 0.5) * 3.0
            v = (cz0 - co.z) * 6.0 + math.hypot(co.x, co.y - HEAD_Y) * 2.0
            uv[li].uv = (u, v)


if hair_style in ("short", "medium", "long", "ponytail", "bun"):
    infl = {"short": 0.008, "medium": 0.016, "long": 0.014, "ponytail": 0.006, "bun": 0.006}[hair_style]
    hair_obj = build_part("Hair", lambda f: all(is_hair[v.index] for v in f.verts), infl, M_HAIR,
                          smooth=4 if hair_style != "short" else 3, bsmooth=8)
    # A bit of volume on top for medium and long hair.
    if hair_style in ("medium", "long"):
        for v in hair_obj.data.vertices:
            k = max(0.0, (v.co.z - (EYE_Z + 0.04)) / max(HEAD_TOP - EYE_Z - 0.04, 0.01))
            d = Vector((v.co.x, v.co.y - HEAD_Y, 0.0))
            if d.length > 1e-4:
                v.co += d.normalized() * 0.006 * k
            v.co.z += 0.008 * k
    set_uv_crown(hair_obj)
    parts.append(hair_obj)


def new_obj(name, vcos, faces, weights, material, uvs=None):
    """Creates a skinned mesh object. weights: list of {bone: w} per vertex. uvs: per-face-corner list."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in vcos], [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    groups = {}
    for i, wd in enumerate(weights):
        for b, w in wd.items():
            if w <= 0.0:
                continue
            if b not in groups:
                groups[b] = obj.vertex_groups.new(name=b)
            groups[b].add([i], w, 'REPLACE')
    me.materials.append(material)
    uvl = me.uv_layers.new(name="UVMap")
    if uvs:
        k = 0
        for poly in me.polygons:
            for li in poly.loop_indices:
                uvl.data[li].uv = uvs[k]
                k += 1
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    obj.parent = rig
    for p in me.polygons:
        p.use_smooth = True
    return obj


def grid_faces(rows, cols, wrap=False):
    f = []
    cc = cols if wrap else cols - 1
    for r in range(rows - 1):
        for c in range(cc):
            a = r * cols + c
            b = r * cols + (c + 1) % cols
            f.append((a, a + cols, b + cols, b))
    return f


def bvh_of(objs):
    vs, fs, off = [], [], 0
    for o in objs:
        me = o.data
        vs.extend([v.co.copy() for v in me.vertices])
        fs.extend([[i + off for i in p.vertices] for p in me.polygons])
        off += len(me.vertices)
    return BVHTree.FromPolygons(vs, fs)


def push_out(bvh, p, min_d, direction):
    """Moves p along direction until it is outside the surfaces and at least min_d away."""
    for _ in range(40):
        loc, nrm, _, dist = bvh.find_nearest(p)
        if loc is None:
            return p
        outside = (p - loc).dot(nrm) > 0
        if outside and dist >= min_d:
            return p
        p = p + direction * 0.004
    return p


if hair_style == "long":
    # A curtain of hair from the back and sides of the head down past the shoulders.
    body_bvh = bvh_of([hair_obj] + parts[:1])
    z0 = EYE_Z + 0.075
    length = float(P.get("hair_len", 0.2))
    z1 = SHOULDER_Z - length
    prof = head_radius_at(z0)
    NC, NR = 17, 9
    span = math.radians(102)
    vcos, wts, uvs_v = [], [], []
    rows = []
    for r in range(NR):
        t = r / (NR - 1)
        row = []
        for c in range(NC):
            t = r / (NR - 1)
            # 0 = straight back (+Y; the face looks to -Y). Lower rows gather behind the shoulders.
            a = (c / (NC - 1) - 0.5) * 2 * span * (1.0 - 0.38 * t)
            r0 = prof_at(prof, a) + (0.0 if r == 0 else 0.013)
            zz = z0 + (z1 - z0) * t
            side = abs(a) / span                                 # 0 at the back, 1 at the sides
            zz += t * 0.05 * side                                # a touch shorter at the sides
            zz -= t * 0.03 * (1 - side) ** 2                     # and a soft V at the back
            rr = r0 * (1.0 + t * 0.12)
            p = Vector((math.sin(a) * rr, HEAD_Y + math.cos(a) * rr, zz))
            out = Vector((math.sin(a), math.cos(a), 0.0))
            if r > 0:
                p = push_out(body_bvh, p, 0.004 if zz > CHIN_Z else 0.012, out)
            row.append(p)
        rows.append(row)
    # Monotonic outward flare row by row (no zig-zag), then a smoothing pass.
    for r in range(1, NR):
        if rows[r][0].z > CHIN_Z:
            continue
        for c in range(NC):
            prev, cur = rows[r - 1][c], rows[r][c]
            pr = math.hypot(prev.x, prev.y - HEAD_Y)
            cr = math.hypot(cur.x, cur.y - HEAD_Y)
            if cr < pr:
                a = math.atan2(cur.x, cur.y - HEAD_Y)
                rows[r][c] = Vector((math.sin(a) * pr, HEAD_Y + math.cos(a) * pr, cur.z))
    for r in range(NR):
        for c in range(NC):
            t = r / (NR - 1)
            vcos.append(rows[r][c])
            wh = max(0.0, 1.0 - t * 1.4)
            wts.append({"head": wh, "neck_01": min(t * 1.4, 1.0) * 0.5, "spine_03": min(t * 1.4, 1.0) * 0.5})
    faces = grid_faces(NR, NC)
    m0 = NC // 2
    n0 = (vcos[NC + m0] - vcos[m0]).cross(vcos[m0 + 1] - vcos[m0])
    if n0.dot(Vector((vcos[m0].x, vcos[m0].y - HEAD_Y, 0))) < 0:
        faces = [tuple(reversed(f)) for f in faces]
    for f in faces:
        for vi in f:
            r, c = divmod(vi, NC)
            uvs_v.append((c / (NC - 1) * 2.5, r / (NR - 1) * 2.0 + 0.6))
    parts.append(new_obj("HairLong", vcos, faces, wts, M_HAIR, uvs_v))

if hair_style in ("ponytail", "bun"):
    prof = head_radius_at(EYE_Z + 0.05)
    rb = prof_at(prof, 0.0)
    base = Vector((0.0, HEAD_Y + rb + 0.004, EYE_Z + 0.05))
    if hair_style == "ponytail":
        path = [base + Vector(d) for d in [(0, -0.01, 0), (0, 0.035, -0.015), (0, 0.06, -0.08), (0, 0.065, -0.16), (0, 0.055, -0.24), (0, 0.045, -0.3)]]
        radii = [0.028, 0.03, 0.026, 0.021, 0.014, 0.004]
    else:
        path = [base + Vector(d) for d in [(0, -0.01, 0.02), (0, 0.015, 0.03), (0, 0.04, 0.032), (0, 0.06, 0.03), (0, 0.075, 0.025)]]
        radii = [0.02, 0.045, 0.05, 0.04, 0.005]
    SEG = 10
    vcos, wts, uvs_v = [], [], []
    for k, (p, r) in enumerate(zip(path, radii)):
        tang = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
        side = Vector((1, 0, 0))
        upv = tang.cross(side).normalized()
        for s in range(SEG):
            a = s / SEG * 2 * math.pi
            vcos.append(p + side * math.cos(a) * r * (1.15 if hair_style == "bun" else 1.0) + upv * math.sin(a) * r)
            t = k / (len(path) - 1)
            wts.append({"head": 1.0 - 0.5 * t * (hair_style == "ponytail"), "neck_01": 0.5 * t * (hair_style == "ponytail")})
    faces = grid_faces(len(path), SEG, wrap=True)
    for f in faces:
        for vi in f:
            r, c = divmod(vi, SEG)
            uvs_v.append((c / SEG * 1.5, r / (len(path) - 1) * 1.5))
    parts.append(new_obj("HairTie", vcos, faces, wts, M_HAIR, uvs_v))

# =====================================================================  eyes, lashes
EYE_IMG = None


def make_eye_texture():
    T = 256
    iris = np.array(P.get("iris", [0.32, 0.2, 0.1]), np.float32)
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    u = (xx + 0.5) / T * 2 - 1
    v = (yy + 0.5) / T * 2 - 1
    r = np.hypot(u, v)
    a = np.arctan2(v, u)
    col = np.ones((T, T, 3), np.float32) * np.array([0.93, 0.9, 0.87])
    # Sclera: pinker and darker toward the corners, a few faint veins.
    edge = np.clip((r - 0.55) / 0.45, 0, 1)[..., None]
    col = col * (1 - edge * 0.35) + np.array([0.85, 0.62, 0.58]) * edge * 0.35
    vr = np.random.default_rng(SEED + 3)
    vein = np.zeros((T, T), np.float32)
    for _ in range(14):
        ang = vr.uniform(0, 2 * math.pi)
        wig = vr.uniform(2, 6)
        d = np.abs(np.sin((a - ang) * 1.0) * r + 0.004 * np.sin(r * wig * 10))
        vein += np.exp(-(d / 0.006) ** 2) * np.clip((r - 0.5) / 0.4, 0, 1)
    col = col * (1 - vein[..., None] * 0.25) + np.array([0.75, 0.3, 0.3]) * vein[..., None] * 0.25
    # Iris: radial fibres, darker limbal ring, lighter collarette around the pupil.
    IR, PR = 0.5, 0.2
    fib = noise(T, 1, 11)
    ang_n = np.interp((a + math.pi) / (2 * math.pi) * 180, np.arange(181), np.random.default_rng(SEED + 4).random(181))
    fibres = 0.75 + 0.35 * ang_n * (0.6 + 0.4 * fib)
    ir = np.clip((r - PR) / (IR - PR), 0, 1)
    icol = iris[None, None, :] * fibres[..., None]
    icol = icol * (1.0 + (1 - ir[..., None]) * 0.6 * np.exp(-((ir[..., None] - 0.2) / 0.15) ** 2))
    icol *= (1 - np.clip((ir - 0.8) / 0.2, 0, 1) ** 2 * 0.6)[..., None]
    in_iris = np.clip((IR - r) / 0.02, 0, 1)[..., None]
    col = col * (1 - in_iris) + icol * in_iris
    in_pupil = np.clip((PR - r) / 0.015, 0, 1)[..., None]
    col = col * (1 - in_pupil) + np.array([0.015, 0.015, 0.018]) * in_pupil
    path = f"{WORK}/eyes.jpg"
    save_rgb(col, path, 92)
    return path


eyes = build_part("Eyes", lambda f: all(is_eye[v.index] for v in f.verts), 0.0, mat("eyes", (1, 1, 1), 0.06, image=make_eye_texture()), smooth=0, rim=False, bsmooth=0)
emesh = eyes.data
centres = {}
for side in ("l", "r"):
    pts = [v.co for v in emesh.vertices if (v.co.x > 0) == (side == "l")]
    centres[side] = sum(pts, Vector()) / max(len(pts), 1)
euv = emesh.uv_layers.active.data
for poly in emesh.polygons:
    for li in poly.loop_indices:
        co = emesh.vertices[emesh.loops[li].vertex_index].co
        c = centres["l" if co.x > 0 else "r"]
        d = (co - c).normalized()
        if d.y > 0.2:                     # back of the eyeball: plain sclera corner
            euv[li].uv = (0.02, 0.02)
        else:
            euv[li].uv = (0.5 + d.x * 0.5, 0.5 + d.z * 0.5)
parts.append(eyes)
parts.append(build_part("Lashes", lambda f: all(is_lash[v.index] for v in f.verts), 0.0, M_LASH, smooth=0, rim=False, bsmooth=0))

# =====================================================================  accessories
def box(cx_, cy_, cz_, sx, sy, sz):
    vs = [(cx_ + dx * sx, cy_ + dy * sy, cz_ + dz * sz) for dz in (-1, 1) for dy in (-1, 1) for dx in (-1, 1)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return vs, fs


def merge(chunks):
    vs, fs = [], []
    for cv, cf in chunks:
        off = len(vs)
        vs.extend(cv)
        fs.extend([tuple(i + off for i in f) for f in cf])
    return vs, fs


if P.get("glasses", "none") != "none":
    sun = P["glasses"] == "sun"
    M_FRAME = mat("frame", lin(P.get("frame", [0.05, 0.05, 0.06])), 0.35)
    gy = EYE_FRONT - 0.011
    chunks = []
    HW, HH = 0.025, 0.017
    for s in (1, -1):
        cxp = s * (EYE_X + 0.002)
        ring_o, ring_i = [], []
        N = 16
        for k in range(N):
            a = k / N * 2 * math.pi
            # Rounded rectangle via superellipse.
            ca, sa = math.cos(a), math.sin(a)
            ex = abs(ca) ** 0.6 * (1 if ca >= 0 else -1)
            ez = abs(sa) ** 0.6 * (1 if sa >= 0 else -1)
            ring_o.append((cxp + ex * (HW + 0.003), gy, EYE_Z - 0.002 + ez * (HH + 0.003)))
            ring_i.append((cxp + ex * HW, gy, EYE_Z - 0.002 + ez * HH))
        vs = ring_o + ring_i
        fs = [(k, (k + 1) % N, N + (k + 1) % N, N + k) for k in range(N)]
        chunks.append((vs, fs))
        # temple arm toward the ear
        hp = head_radius_at(EYE_Z + 0.005)
        ear_x = s * (prof_at(hp, s * math.pi / 2) + 0.004)
        chunks.append(box((cxp + s * (HW + 0.002) + ear_x) / 2, (gy + HEAD_Y + 0.01) / 2, EYE_Z + 0.006,
                          abs(ear_x - (cxp + s * (HW + 0.002))) / 2 + 0.002, abs(HEAD_Y + 0.01 - gy) / 2, 0.0018))
    chunks.append(box(0.0, gy, EYE_Z + 0.006, EYE_X - HW, 0.002, 0.002))       # bridge
    vs, fs = merge(chunks)
    parts.append(new_obj("Glasses", vs, fs, [{"head": 1.0}] * len(vs), M_FRAME))
    if sun:
        M_LENS = mat("lens", (0.015, 0.018, 0.022), 0.12, double=True)
        lv, lf = [], []
        for s in (1, -1):
            cxp = s * (EYE_X + 0.002)
            off = len(lv)
            lv.append((cxp, gy + 0.0005, EYE_Z - 0.002))
            N = 16
            for k in range(N):
                a = k / N * 2 * math.pi
                ca, sa = math.cos(a), math.sin(a)
                lv.append((cxp + abs(ca) ** 0.6 * math.copysign(1, ca) * HW, gy + 0.0005, EYE_Z - 0.002 + abs(sa) ** 0.6 * math.copysign(1, sa) * HH))
            lf.extend([(off, off + 1 + k, off + 1 + (k + 1) % N) for k in range(N)])
        parts.append(new_obj("Lens", lv, lf, [{"head": 1.0}] * len(lv), M_LENS))

if hat != "none":
    hat_rgb = P.get("hat_color", [0.12, 0.13, 0.16])
    M_HAT = mat("hat", lin(hat_rgb), 0.9, image=KNIT, normal=FABRIC_N, scale=6.0, double=True)
    hz = EYE_Z + (0.042 if hat == "cap" else 0.03)

    def hat_keep(f):
        for v in f.verts:
            i = v.index
            if not is_body[i] or w_head[i] < 0.5 or w_ears[i] > 0.3:
                return False
            if CO[i][2] < hz - (0.0 if CO[i][1] < HEAD_Y else 0.012):
                return False
        return True
    hobj = build_part("Hat", hat_keep, 0.02 if hat == "cap" else 0.024, M_HAT, smooth=6, bsmooth=8)
    if hat == "beanie":
        for v in hobj.data.vertices:
            k = max(0.0, (v.co.z - hz) / max(HEAD_TOP - hz, 0.01))
            v.co.z += 0.012 * k * k
    parts.append(hobj)
    if hat == "cap":
        prof = head_radius_at(hz + 0.004)
        vs, fs = [], []
        N = 9
        for k in range(N):
            a = (k / (N - 1) - 0.5) * math.radians(150)          # around the front
            r_in = prof_at(prof, math.pi - a) + 0.018
            dirv = Vector((math.sin(a), -math.cos(a), 0))
            base_p = Vector((0, HEAD_Y, hz + 0.009)) + dirv * r_in
            # The brim is longer in the middle than at the sides.
            reach = 0.075 * math.cos(a * 0.9) ** 1.5 + 0.006
            tip = base_p + dirv * reach + Vector((0, 0, -0.018 * math.cos(a)))
            vs.extend([tuple(base_p), tuple(tip)])
        for k in range(N - 1):
            fs.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
        # (math.sin/cos above use the angle from the face direction: -Y is forward.)
        vs = [(x, y, z) for (x, y, z) in vs]
        parts.append(new_obj("Brim", vs, fs, [{"head": 1.0}] * len(vs), M_HAT))

if "backpack" in P:
    M_BAG = mat("bag", lin(P["backpack"]), 0.75, image=KNIT, normal=FABRIC_N, scale=4.0, double=True)
    bvh = bvh_of(parts[:1])
    bz = SHOULDER_Z - 0.2
    back_y = float(Y[is_body & (w_torso > 0.5) & (np.abs(Z - bz) < 0.03) & (np.abs(X) < 0.08)].max())
    back_y += INFLATE["Top"] if top in ("jacket", "hoodie") else INFLATE["Shirt"]
    sx, sz, sy = 0.15, 0.2, 0.07
    cyb = back_y + sy + 0.008
    chunks = [box(0, cyb, bz, sx, sy, sz), box(0, cyb + sy + 0.012, bz - 0.06, sx * 0.75, 0.015, sz * 0.45)]
    vs, fs = merge(chunks)
    # Round the box corners a little by pulling vertices toward the centre.
    vs = [(x * 0.93, y, z) if abs(z - bz) > sz * 0.9 else (x, y, z) for (x, y, z) in vs]
    w_bag = [{"spine_03": 1.0}] * len(vs)
    # Straps over the shoulders.
    for s in (1, -1):
        pts = []
        for k in range(8):
            t = k / 7
            a = t * math.pi * 1.1
            p = Vector((s * 0.1, NECK.y + math.cos(a) * 0.12, SHOULDER_Z - 0.02 + math.sin(a) * 0.06 - max(0, t - 0.5) * 0.25))
            loc, nrm, _, _ = bvh.find_nearest(p)
            if loc is not None:
                p = loc + nrm * 0.007
            pts.append(p)
        off = len(vs)
        for p in pts:
            vs.append((p.x - 0.02, p.y, p.z))
            vs.append((p.x + 0.02, p.y, p.z))
            w_bag.append({"spine_03": 1.0})
            w_bag.append({"spine_03": 1.0})
        for k in range(7):
            a = off + 2 * k
            fs.append((a, a + 1, a + 3, a + 2))
    parts.append(new_obj("Backpack", vs, fs, w_bag, M_BAG))


# =====================================================================  skin (body) + AO bake
def skin_keep(f):
    idx = [v.index for v in f.verts]
    if not all(is_body[i] for i in idx):
        return False
    rs = [regions[i] for i in idx]
    return not all(r is not None for r in rs)     # skin completely hidden under clothes is dropped


body = build_part("Body", skin_keep, 0.0, M_SKIN, smooth=0, rim=False, bsmooth=0)
parts.append(body)
bpy.data.objects.remove(human, do_unlink=True)

# Ambient occlusion baked into the skin: eye sockets, nostrils, ears, under the hair and collar.
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = int(P.get("ao_samples", 48))
sc.cycles.device = 'CPU'
if sc.world is None:
    sc.world = bpy.data.worlds.new("w")
sc.world.light_settings.distance = 0.12
AO_IMG = bpy.data.images.new("ao_bake", S // 2, S // 2, alpha=False)
bake_node = nt.nodes.new("ShaderNodeTexImage")
bake_node.image = AO_IMG
nt.nodes.active = bake_node
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
ao = None
try:
    bpy.ops.object.bake(type='AO', margin=6, use_clear=True)
    ao = np.array(AO_IMG.pixels[:], np.float32).reshape(S // 2, S // 2, 4)[::-1, :, 0]
    ao = np.asarray(Image.fromarray((np.clip(ao, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255.0
except Exception as e:  # noqa
    print("AO_BAKE_FAILED", e)
nt.nodes.remove(bake_node)
if ao is not None:
    # Soft, warm occlusion (skin scatters light, so the shadows lean red).
    occ = 1.0 - np.clip(ao, 0, 1)
    occ = np.clip(occ * 1.15, 0, 1) ** 1.2
    shade = 1.0 - occ[..., None] * np.array([0.5, 0.62, 0.65])
    col = col * shade
skin_path = f"{WORK}/skin.jpg"
save_rgb(col, skin_path, 90)
skin_img = bpy.data.images.load(skin_path)
alb_node.image = skin_img
bpy.data.images.remove(SKIN_IMG)
skin_img.name = "skin"

# =====================================================================  join, decimate, export


for o in parts:
    print("PART", o.name, tri_count(o))

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
tris = tri_count(char)
if tris > budget * 1.02:
    decimate_to(char, budget)
# Drop vertex groups that are not bones (helpers, masks).
bone_names = {b.name for b in rig.data.bones}
for g in list(char.vertex_groups):
    if g.name not in bone_names:
        char.vertex_groups.remove(g)
bpy.ops.object.shade_smooth()
tris = tri_count(char)
print("CHAR_TRIS", tris, "VERTS", len(char.data.vertices), "MATS", len(char.data.materials))

bpy.ops.object.select_all(action='DESELECT')
char.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                          export_skins=True, export_animations=False, export_apply=False,
                          export_image_format='JPEG', export_jpeg_quality=88,
                          export_yup=True)
print("EXPORTED", OUT, os.path.getsize(OUT))
