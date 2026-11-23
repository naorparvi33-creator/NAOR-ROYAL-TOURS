"""Sets the textures that Godot extracted from the character .glb files to VRAM compression
(ETC2/ASTC on phones) and marks the normal maps, then forces a reimport of those files.

Run from the game folder after a first `godot --headless --import .`:
    python3 tools/chargen/fix_imports.py && godot --headless --import .
"""
import glob
import os
import re

GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
changed = 0
for imp in sorted(glob.glob(os.path.join(GAME, "assets/characters/*.jpg.import")) +
                  glob.glob(os.path.join(GAME, "assets/characters/*.png.import"))):
    name = os.path.basename(imp)[:-len(".jpg.import")]
    is_normal = name.endswith("_n") or "normal" in name
    s = open(imp).read()
    new = re.sub(r"compress/mode=\d+", "compress/mode=2", s)
    new = re.sub(r"compress/normal_map=\d+", "compress/normal_map=%d" % (1 if is_normal else 2), new)
    new = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", new)
    # Pedestrian normal maps are only seen within the LOD distance (12-30 m): 512 px keeps
    # the APK size down (1.4 MB -> 0.35 MB each as ETC2). The player keeps full size.
    if is_normal and name.startswith("ped_") and not name.endswith("hair_cards_n"):
        new = re.sub(r"process/size_limit=\d+", "process/size_limit=512", new)
    if new != s:
        open(imp, "w").write(new)
        # Drop the cached import so Godot rebuilds it with the new settings.
        m = re.search(r'path="res://(\.godot/imported/[^"]+)"', new)
        if m:
            for f in glob.glob(os.path.join(GAME, m.group(1).rsplit(".", 1)[0] + ".*")):
                os.remove(f)
        for f in glob.glob(os.path.join(GAME, ".godot/imported", os.path.basename(imp)[:-len(".import")] + "-*")):
            os.remove(f)
        changed += 1
print("fix_imports: updated", changed, "texture import settings")
