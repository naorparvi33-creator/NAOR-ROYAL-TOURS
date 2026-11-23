#!/bin/bash
# Generates the playable character and the pedestrian variants.
OUT="$(cd "$(dirname "$0")/../.." && pwd)/assets/characters"
mkdir -p $OUT
gen() { timeout 900 python3 "$(dirname "$0")/build_character.py" "$OUT/$1.glb" "$2" 2>&1 | grep -E "CHAR_TRIS|EXPORTED|Error|Traceback" | sed "s|^|$1: |"; }
gen player '{"gender":1.0,"muscle":0.62,"height":0.55,"weight":0.5,"skin":[0.78,0.6,0.48],"hair":[0.08,0.06,0.05],"shirt":[0.88,0.88,0.86],"shoes":[0.92,0.92,0.9],"decimate":0.5}'
gen ped_01 '{"gender":0.0,"age":0.45,"height":0.45,"weight":0.45,"race":{"caucasian":0.8,"african":0.0,"asian":0.2},"skin":[0.86,0.7,0.6],"hair":[0.35,0.22,0.12],"shirt":[0.75,0.2,0.25],"pants":[0.25,0.25,0.3],"shoes":[0.15,0.15,0.15],"decimate":0.33}'
gen ped_02 '{"gender":1.0,"age":0.7,"weight":0.7,"muscle":0.4,"race":{"caucasian":0.9,"african":0.0,"asian":0.1},"skin":[0.82,0.64,0.54],"hair":[0.55,0.55,0.55],"shirt":[0.3,0.4,0.6],"sleeves":"long","pants":[0.45,0.4,0.32],"shoes":[0.3,0.2,0.12],"decimate":0.33}'
gen ped_03 '{"gender":1.0,"age":0.35,"muscle":0.7,"height":0.65,"race":{"caucasian":0.0,"african":1.0,"asian":0.0},"skin":[0.42,0.28,0.2],"hair":[0.04,0.03,0.03],"shirt":[0.15,0.15,0.17],"shoes":[0.9,0.9,0.9],"decimate":0.33}'
gen ped_04 '{"gender":0.0,"age":0.4,"height":0.4,"weight":0.4,"race":{"caucasian":0.0,"african":0.0,"asian":1.0},"skin":[0.85,0.7,0.58],"hair":[0.05,0.04,0.04],"shirt":[0.95,0.9,0.7],"pants":[0.15,0.15,0.2],"shoes":[0.85,0.85,0.85],"decimate":0.33}'
gen ped_05 '{"gender":1.0,"age":0.5,"weight":0.6,"race":{"caucasian":0.4,"african":0.3,"asian":0.3},"skin":[0.66,0.48,0.36],"hair":[0.12,0.08,0.05],"shirt":[0.3,0.55,0.35],"pants":[0.2,0.2,0.22],"shoes":[0.4,0.28,0.18],"decimate":0.33}'
gen ped_06 '{"gender":0.0,"age":0.6,"weight":0.6,"race":{"caucasian":0.2,"african":0.8,"asian":0.0},"skin":[0.5,0.34,0.25],"hair":[0.06,0.05,0.04],"shirt":[0.55,0.35,0.6],"sleeves":"long","shoes":[0.2,0.2,0.2],"decimate":0.33}'
gen ped_07 '{"gender":1.0,"age":0.3,"weight":0.35,"height":0.5,"race":{"caucasian":1.0,"african":0.0,"asian":0.0},"skin":[0.9,0.74,0.64],"hair":[0.6,0.45,0.25],"shirt":[0.9,0.55,0.2],"pants":[0.7,0.65,0.55],"shoes":[0.9,0.9,0.9],"decimate":0.33}'
gen ped_08 '{"gender":0.0,"age":0.3,"height":0.55,"race":{"caucasian":0.5,"african":0.0,"asian":0.5},"skin":[0.84,0.66,0.54],"hair":[0.2,0.12,0.08],"shirt":[0.2,0.3,0.45],"shoes":[0.95,0.95,0.95],"decimate":0.33}'
echo CAST_DONE
