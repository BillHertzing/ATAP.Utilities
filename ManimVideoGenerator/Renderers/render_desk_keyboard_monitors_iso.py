#!/usr/bin/env python3
"""
Render script for DeskKeyboardMonitors ISO Projection Scene.
Renders DeskKeyboardMonitors_ISO_Projection to MP4 in _generated/.
"""
import subprocess
import sys
import shutil
from datetime import datetime
from pathlib import Path

PYTHON_EXE     = r"C:\Python311\python.exe"
SCRIPT_DIR     = Path(__file__).resolve().parents[1]
OUTPUT_DIR     = SCRIPT_DIR / "_generated"
SCENE_FILE     = SCRIPT_DIR / "Scenes" / "desk_keyboard_monitors_iso_scene.py"
SCENE_NAME     = "DeskKeyboardMonitors_ISO_Projection"
RUN_OUTPUT_DIR = OUTPUT_DIR / f"_render_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def render(quality: str = "h") -> int:
    """Render scene. quality: l/m/h/p/k (Manim -q<letter>)."""
    print("=" * 70)
    print("DeskKeyboardMonitors ISO Projection Renderer")
    print("=" * 70)
    print(f"Scene file : {SCENE_FILE}")
    print(f"Scene name : {SCENE_NAME}")
    print(f"Output dir : {RUN_OUTPUT_DIR}")
    print(f"Quality    : -q{quality}")
    print()

    RUN_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    cmd = [
        PYTHON_EXE, "-m", "manim",
        str(SCENE_FILE),
        SCENE_NAME,
        f"-q{quality}",
        "--output_file", SCENE_NAME,
        "--media_dir", str(RUN_OUTPUT_DIR),
    ]
    print("Running:", " ".join(cmd))
    print()

    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))

    print()
    if result.returncode == 0:
        stable_copy = OUTPUT_DIR / f"{SCENE_NAME}_latest.mp4"
        # Find the rendered mp4 and copy to a stable name
        mp4s = list(RUN_OUTPUT_DIR.rglob("*.mp4"))
        if mp4s:
            shutil.copy2(mp4s[0], stable_copy)
            print(f"Copied to: {stable_copy}")
        print("Render succeeded.")
    else:
        print(f"Render FAILED (exit {result.returncode}).")

    return result.returncode


if __name__ == "__main__":
    quality = sys.argv[1] if len(sys.argv) > 1 else "h"
    sys.exit(render(quality))
