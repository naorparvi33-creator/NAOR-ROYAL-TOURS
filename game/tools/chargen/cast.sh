#!/bin/bash
# Generates the playable character and the pedestrian cast (all procedural, no photos).
#   ./cast.sh            -> everything
#   ./cast.sh ped_03     -> only the named characters
# Ages: MakeHuman age 0.5 = 25 years, 0.7 ~ 50, 0.875 ~ 70.
# ped_17 = tactical operator look, ped_18 / ped_19 = street-gang looks (all original, unbranded).
# The player keeps light, neutral clothes: the clothing store tints them (interiors.gd).
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(cd "$HERE/../.." && pwd)/assets/characters"
mkdir -p "$OUT"
JOBS=${JOBS:-2}

declare -A CAST
CAST[player]='{"seed":11,"gender":1.0,"age":0.52,"muscle":0.64,"height":0.58,"weight":0.5,"face":0.38,"race":{"caucasian":0.7,"african":0.15,"asian":0.15},"skin":[0.76,0.57,0.44],"iris":[0.26,0.17,0.09],"hair":[0.07,0.055,0.045],"hair_style":"fade","beard":"stubble","top":"tshirt","shirt":[0.86,0.86,0.84],"bottom":"jeans","pants":[0.3,0.4,0.56],"belt":[0.16,0.1,0.06],"shoes":[0.93,0.93,0.91],"tris":16000,"skin_res":2048,"cornea":true,"lod_tris":0}'
CAST[ped_01]='{"seed":101,"gender":0.0,"age":0.45,"height":0.45,"weight":0.42,"race":{"caucasian":0.75,"african":0.05,"asian":0.2},"skin":[0.85,0.68,0.57],"freckles":0.35,"iris":[0.3,0.42,0.22],"hair":[0.3,0.19,0.1],"hair_style":"long","top":"tshirt","shirt":[0.86,0.36,0.32],"bottom":"jeans","pants":[0.42,0.52,0.68],"shoes":[0.95,0.95,0.93],"lipstick":[0.66,0.34,0.34]}'
CAST[ped_02]='{"seed":102,"gender":1.0,"age":0.72,"weight":0.68,"muscle":0.42,"race":{"caucasian":0.9,"african":0.0,"asian":0.1},"skin":[0.82,0.64,0.54],"iris":[0.35,0.45,0.55],"hair":[0.6,0.59,0.57],"hair_style":"short","hairline":0.03,"top":"longsleeve","pattern":"plaid","shirt":[0.25,0.35,0.6],"stripe":[0.1,0.12,0.2],"bottom":"chinos","pants":[0.62,0.55,0.4],"belt":[0.2,0.12,0.06],"shoes_style":"flats","shoes":[0.22,0.13,0.07],"glasses":"clear"}'
CAST[ped_03]='{"seed":103,"gender":1.0,"age":0.42,"muscle":0.72,"height":0.65,"race":{"caucasian":0.0,"african":1.0,"asian":0.0},"skin":[0.4,0.26,0.18],"iris":[0.16,0.1,0.06],"hair":[0.04,0.03,0.03],"hair_style":"fade","beard":"short","top":"tshirt","pattern":"print","shirt":[0.12,0.12,0.13],"stripe":[0.85,0.7,0.3],"bottom":"jeans","pants":[0.16,0.2,0.3],"shoes":[0.92,0.92,0.92]}'
CAST[ped_04]='{"seed":104,"gender":0.0,"age":0.45,"height":0.4,"weight":0.4,"race":{"caucasian":0.0,"african":0.0,"asian":1.0},"skin":[0.86,0.71,0.59],"iris":[0.14,0.09,0.06],"hair":[0.05,0.04,0.04],"hair_style":"bun","top":"longsleeve","shirt":[0.95,0.9,0.78],"bottom":"trousers","pants":[0.12,0.12,0.15],"shoes":[0.85,0.85,0.85],"backpack":[0.55,0.45,0.35],"lipstick":[0.62,0.3,0.3]}'
CAST[ped_05]='{"seed":105,"gender":1.0,"age":0.5,"weight":0.6,"race":{"caucasian":0.4,"african":0.35,"asian":0.25},"skin":[0.62,0.44,0.32],"iris":[0.2,0.13,0.07],"hair":[0.1,0.07,0.05],"hair_style":"curly","beard":"stubble","top":"hoodie","jacket":[0.3,0.38,0.32],"bottom":"jeans","pants":[0.3,0.36,0.46],"shoes_style":"boots","shoes":[0.38,0.26,0.15]}'
CAST[ped_06]='{"seed":106,"gender":0.0,"age":0.62,"weight":0.62,"race":{"caucasian":0.2,"african":0.8,"asian":0.0},"skin":[0.5,0.34,0.25],"iris":[0.15,0.09,0.05],"hair":[0.06,0.05,0.04],"hair_style":"curly","top":"longsleeve","shirt":[0.5,0.3,0.58],"bottom":"skirt","pants":[0.25,0.25,0.28],"skirt":[0.28,0.28,0.3],"skirt_len":-0.18,"shoes_style":"flats","shoes":[0.08,0.08,0.08],"lipstick":[0.45,0.18,0.2]}'
CAST[ped_07]='{"seed":107,"gender":1.0,"age":0.5,"weight":0.5,"muscle":0.7,"height":0.6,"race":{"caucasian":0.9,"african":0.0,"asian":0.1},"skin":[0.8,0.62,0.5],"iris":[0.3,0.4,0.42],"hair":[0.09,0.07,0.06],"hair_style":"slick","beard":"goatee","top":"leather","jacket":[0.07,0.065,0.065],"shirt":[0.16,0.16,0.17],"bottom":"jeans","pants":[0.14,0.15,0.2],"belt":[0.08,0.06,0.05],"shoes_style":"boots","shoes":[0.07,0.06,0.06],"glasses":"sun"}'
CAST[ped_08]='{"seed":108,"gender":0.0,"age":0.36,"height":0.55,"race":{"caucasian":0.5,"african":0.0,"asian":0.5},"skin":[0.84,0.66,0.54],"iris":[0.25,0.16,0.08],"hair":[0.2,0.12,0.08],"hair_style":"ponytail","top":"jacket","jacket":[0.14,0.2,0.34],"shirt":[0.95,0.95,0.93],"bottom":"jeans","pants":[0.24,0.3,0.42],"shoes":[0.95,0.95,0.95],"lipstick":[0.62,0.3,0.32]}'
CAST[ped_09]='{"seed":109,"gender":1.0,"age":0.4,"weight":0.5,"race":{"caucasian":0.85,"african":0.1,"asian":0.05},"skin":[0.74,0.55,0.42],"iris":[0.18,0.11,0.06],"hair":[0.05,0.04,0.035],"hair_style":"short","beard":"stubble","top":"tshirt","pattern":"raglan","shirt":[0.92,0.92,0.9],"stripe":[0.15,0.18,0.25],"bottom":"jeans","pants":[0.1,0.1,0.12],"shoes":[0.15,0.15,0.16],"sole":[0.9,0.9,0.88],"hat":"cap","hat_color":[0.12,0.12,0.14]}'
CAST[ped_10]='{"seed":110,"gender":0.0,"age":0.58,"weight":0.5,"race":{"caucasian":1.0,"african":0.0,"asian":0.0},"skin":[0.88,0.72,0.62],"freckles":0.6,"iris":[0.32,0.46,0.28],"hair":[0.45,0.17,0.08],"hair_style":"medium","top":"dress","shirt":[0.2,0.45,0.32],"shoes_style":"flats","shoes":[0.6,0.45,0.32],"glasses":"clear","frame":[0.35,0.2,0.1]}'
CAST[ped_11]='{"seed":111,"gender":1.0,"age":0.5,"weight":0.45,"race":{"caucasian":0.0,"african":0.0,"asian":1.0},"skin":[0.84,0.68,0.54],"iris":[0.12,0.08,0.05],"hair":[0.04,0.035,0.03],"hair_style":"slick","top":"suit","jacket":[0.16,0.17,0.2],"shirt":[0.93,0.94,0.96],"tie":[0.22,0.12,0.32],"bottom":"trousers","pants":[0.16,0.17,0.2],"shoes_style":"flats","shoes":[0.05,0.04,0.04],"glasses":"clear"}'
CAST[ped_12]='{"seed":112,"gender":0.0,"age":0.33,"weight":0.4,"height":0.6,"race":{"caucasian":0.0,"african":1.0,"asian":0.0},"skin":[0.36,0.24,0.17],"iris":[0.1,0.06,0.04],"hair":[0.03,0.025,0.02],"hair_style":"ponytail","top":"hoodie","jacket":[0.62,0.62,0.64],"bottom":"sweats","pants":[0.08,0.08,0.09],"stripe":[0.9,0.9,0.9],"shoes":[0.96,0.96,0.96],"lipstick":[0.35,0.15,0.15]}'
CAST[ped_13]='{"seed":113,"gender":1.0,"age":0.66,"weight":0.62,"muscle":0.6,"race":{"caucasian":1.0,"african":0.0,"asian":0.0},"skin":[0.85,0.66,0.56],"iris":[0.35,0.42,0.45],"hair":[0.32,0.24,0.17],"hair_style":"bald","beard":"full","top":"jacket","jacket":[0.3,0.2,0.12],"shirt":[0.45,0.45,0.46],"bottom":"jeans","pants":[0.18,0.24,0.36],"shoes_style":"boots","shoes":[0.1,0.08,0.07]}'
CAST[ped_14]='{"seed":114,"gender":0.0,"age":0.4,"weight":0.4,"race":{"caucasian":1.0,"african":0.0,"asian":0.0},"skin":[0.88,0.7,0.58],"iris":[0.28,0.45,0.65],"hair":[0.78,0.64,0.4],"hair_style":"long","hair_len":0.26,"top":"tank","shirt":[0.96,0.96,0.94],"bottom":"shorts","pants":[0.45,0.58,0.75],"shorts_len":0.16,"shoes":[0.95,0.6,0.62],"glasses":"sun","lipstick":[0.75,0.38,0.4]}'
CAST[ped_15]='{"seed":115,"gender":1.0,"age":0.44,"weight":0.55,"race":{"caucasian":0.1,"african":0.9,"asian":0.0},"skin":[0.46,0.31,0.22],"iris":[0.14,0.09,0.05],"hair":[0.04,0.03,0.03],"hair_style":"short","beard":"short","top":"jacket","jacket":[0.32,0.34,0.22],"shirt":[0.9,0.9,0.88],"bottom":"chinos","pants":[0.68,0.6,0.45],"shoes_style":"boots","shoes":[0.42,0.3,0.18],"hat":"beanie","hat_color":[0.55,0.15,0.1]}'
CAST[ped_16]='{"seed":116,"gender":0.0,"age":0.82,"weight":0.58,"height":0.35,"race":{"caucasian":0.0,"african":0.0,"asian":1.0},"skin":[0.84,0.7,0.6],"iris":[0.14,0.1,0.07],"hair":[0.74,0.74,0.72],"hair_style":"short","top":"jacket","jacket":[0.78,0.7,0.56],"shirt":[0.55,0.25,0.3],"bottom":"trousers","pants":[0.35,0.35,0.37],"shoes_style":"flats","shoes":[0.2,0.15,0.12],"glasses":"clear","frame":[0.6,0.5,0.3]}'
CAST[ped_17]='{"seed":117,"gender":1.0,"age":0.45,"muscle":0.78,"height":0.62,"weight":0.55,"race":{"caucasian":0.6,"african":0.2,"asian":0.2},"skin":[0.72,0.53,0.4],"iris":[0.2,0.14,0.08],"hair":[0.1,0.08,0.06],"hair_style":"fade","beard":"short","top":"longsleeve","pattern":"camo","shirt":[0.6,0.53,0.4],"stripe":[0.3,0.3,0.22],"bottom":"cargo","pants":[0.55,0.48,0.36],"kneepads":[0.2,0.2,0.18],"vest":[0.3,0.32,0.24],"gloves":[0.1,0.1,0.1],"shoes_style":"boots","shoes":[0.45,0.36,0.25],"hat":"helmet","hat_color":[0.4,0.36,0.28],"glasses":"sun"}'
CAST[ped_18]='{"seed":118,"gender":1.0,"age":0.36,"muscle":0.72,"weight":0.48,"race":{"caucasian":0.45,"african":0.25,"asian":0.3},"skin":[0.68,0.48,0.34],"iris":[0.14,0.09,0.05],"hair":[0.05,0.04,0.035],"hair_style":"buzz","beard":"goatee","top":"tank","shirt":[0.95,0.95,0.93],"bottom":"jeans","pants":[0.14,0.17,0.26],"shoes":[0.95,0.95,0.95],"hat":"bandana","hat_color":[0.12,0.2,0.45],"chain":[0.85,0.65,0.3],"tattoos":1.0}'
CAST[ped_19]='{"seed":119,"gender":1.0,"age":0.32,"weight":0.45,"height":0.6,"race":{"caucasian":0.0,"african":1.0,"asian":0.0},"skin":[0.38,0.25,0.18],"iris":[0.1,0.06,0.04],"hair":[0.03,0.025,0.02],"hair_style":"short","beard":"stubble","top":"tshirt","pattern":"print","shirt":[0.08,0.08,0.09],"stripe":[0.78,0.12,0.12],"bottom":"sweats","pants":[0.45,0.45,0.47],"shoes":[0.95,0.95,0.95],"sole":[0.15,0.15,0.15],"hat":"cap_back","hat_color":[0.6,0.08,0.08],"chain":[0.8,0.8,0.82],"tattoos":0.5}'

NAMES=("$@")
[ ${#NAMES[@]} -eq 0 ] && NAMES=(player ped_01 ped_02 ped_03 ped_04 ped_05 ped_06 ped_07 ped_08 ped_09 ped_10 ped_11 ped_12 ped_13 ped_14 ped_15 ped_16 ped_17 ped_18 ped_19)

gen() {
	# Godot extracts the embedded textures next to the .glb: drop the old ones first.
	rm -f "$OUT/$1"_*.jpg "$OUT/$1"_*.jpg.import "$OUT/$1"_*.png "$OUT/$1"_*.png.import
	timeout 1200 python3 "$HERE/build_character.py" "$OUT/$1.glb" "$2" 2>&1 | grep -E "CHAR_TRIS|LOD_TRIS|EXPORTED|Error|Traceback" | sed "s|^|$1: |"
}
running=0
for n in "${NAMES[@]}"; do
	gen "$n" "${CAST[$n]}" &
	running=$((running + 1))
	if [ $running -ge $JOBS ]; then wait -n; running=$((running - 1)); fi
done
wait
echo CAST_DONE
echo "Next: cd game && godot --headless --import . ; python3 tools/chargen/fix_imports.py ; godot --headless --import ."
