"""Loads MPFB2 into headless Blender as a regular user extension."""
import os, shutil, bpy, addon_utils

SRC = "/tmp/mpfb2/src/mpfb"
PKG = "bl_ext.user_default.mpfb"


def enable():
    ext_dir = bpy.utils.user_resource('EXTENSIONS', path="user_default", create=True)
    dst = os.path.join(ext_dir, "mpfb")
    if not os.path.isdir(dst):
        shutil.copytree(SRC, dst)
    bpy.ops.extensions.repo_refresh_all() if hasattr(bpy.ops.extensions, "repo_refresh_all") else None
    mod = addon_utils.enable(PKG, default_set=True, handle_error=None)
    if mod is None:
        raise RuntimeError("could not enable " + PKG)
    return PKG
