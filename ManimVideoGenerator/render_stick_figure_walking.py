#!/usr/bin/env python3
"""
Render script for Stick Figure Walking Scene.
Renders StickFigureWalking to MP4 in _generated/ using Python 3.11 + Manim.
"""
import subprocess
import sys
import shutil
from datetime import datetime
from pathlib import Path

PYTHON_EXE     = r"C:\Python311\python.exe"
SCRIPT_DIR     = Path(__file__).parent.absolute()
OUTPUT_DIR     = SCRIPT_DIR / "_generated"
SCENE_FILE     = SCRIPT_DIR / "Scenes" / "stick_figure_walking_scene.py"
SCENE_NAME     = "StickFigureWalking"
RUN_OUTPUT_DIR = OUTPUT_DIR / f"_render_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def render_walking(quality: str = "h") -> int:
    """Render StickFigureWalking. quality: l/m/h/p/k (Manim -q<letter>)."""
    print("=" * 70)
    print("Stick Figure Walking Renderer")
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
        "--output_file", "StickFigureWalking",
        "--media_dir", str(RUN_OUTPUT_DIR),
    ]
    print("Running:", " ".join(cmd))
    print()

    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))

    print()
    if result.returncode == 0:
        stable_copy = OUTPUT_DIR / "StickFigureWalking_latest.mp4"
        candidates  = list(RUN_OUTPUT_DIR.rglob("*.mp4"))
        if candidates:
            shutil.copy2(candidates[0], stable_copy)
            print(f"Video saved : {candidates[0]}")
            print(f"Stable copy : {stable_copy}")
        else:
            print("Render succeeded but no .mp4 found under output dir.")
    else:
        print(f"Render FAILED (exit code {result.returncode})")

    return result.returncode


if __name__ == "__main__":
    q = sys.argv[1].lstrip("-") if len(sys.argv) > 1 else "h"
    sys.exit(render_walking(quality=q))
