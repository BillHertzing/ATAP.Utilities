#!/usr/bin/env python3
"""
Render script for Stick Figure Base Scene.
Renders the StickFigureBase scene to 1080p @ 60fps MP4 in _generated/ folder.
"""
import subprocess
import sys
import shutil
from datetime import datetime
from pathlib import Path

# Python interpreter that has manim installed
PYTHON_EXE = r"C:\Python311\python.exe"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR      = Path(__file__).parent.absolute()
OUTPUT_DIR      = SCRIPT_DIR / "_generated"
SCENE_FILE      = SCRIPT_DIR / "Scenes" / "stick_figure_base_scene.py"
SCENE_NAME      = "StickFigureBase"
RUN_OUTPUT_DIR  = OUTPUT_DIR / f"_render_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
FINAL_VIDEO     = RUN_OUTPUT_DIR / "videos" / "Scenes" / "stick_figure_base_scene" / "1080p60" / "StickFigureBase.mp4"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Render helper
# ---------------------------------------------------------------------------

def render_stick_figure(quality: str = "h") -> int:
    """
    Render the StickFigureBase scene.

    Args:
        quality: manim quality flag — 'l' (low/480p), 'm' (medium/720p),
                 'h' (high/1080p), 'p' (4K), 'k' (8K).  Default is 'h'.

    Returns:
        subprocess return code (0 = success).
    """
    print("=" * 70)
    print("Stick Figure Base Renderer")
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
        "--output_file", "StickFigureBase",
        "--media_dir", str(RUN_OUTPUT_DIR),
    ]

    print("Running:", " ".join(cmd))
    print()

    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))

    print()
    if result.returncode == 0:
        # Copy output video to a stable location for easy access
        stable_copy = OUTPUT_DIR / "StickFigureBase_latest.mp4"
        candidates = list(RUN_OUTPUT_DIR.rglob("*.mp4"))
        if candidates:
            shutil.copy2(candidates[0], stable_copy)
            print(f"Video saved : {candidates[0]}")
            print(f"Stable copy : {stable_copy}")
        else:
            print("Render succeeded but no .mp4 found under output dir.")
    else:
        print(f"Render FAILED (exit code {result.returncode})")

    return result.returncode


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Accept optional quality flag as first CLI argument (default: high)
    q = sys.argv[1].lstrip("-") if len(sys.argv) > 1 else "h"
    sys.exit(render_stick_figure(quality=q))
