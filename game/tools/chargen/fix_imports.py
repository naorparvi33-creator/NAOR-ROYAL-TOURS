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
for imp in sorted(glob.glob(os.path.join(GAME, "assets/characters/*.jpg.import"))):
    name = os.path.basename(imp)[:-len(".jpg.import")]
    is_normal = name.endswith("_n") or "normal" in name
    s = open(imp).read()
    new = re.sub(r"compress/mode=\d+", "compress/mode=2", s)
    new = re.sub(r"compress/normal_map=\d+", "compress/normal_map=%d" % (1 if is_normal else 2), new)
    new = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", new)
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
