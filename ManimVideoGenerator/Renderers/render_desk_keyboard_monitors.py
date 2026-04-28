#!/usr/bin/env python3
"""
Render script for DeskKeyboardMonitors scene.
Outputs MP4 to ManimVideoGenerator/_generated/
"""
import subprocess
from datetime import datetime
from pathlib import Path

PYTHON_EXE  = r"C:\Python311\python.exe"
SCRIPT_DIR  = Path(__file__).resolve().parents[1]
OUTPUT_DIR  = SCRIPT_DIR / "_generated"
SCENE_FILE  = SCRIPT_DIR / "Scenes" / "desk_keyboard_monitors_scene.py"
SCENE_NAME  = "DeskKeyboardMonitors"


def render(quality: str = "h") -> int:
    run_dir = OUTPUT_DIR / f"_render_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    run_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print(f"Rendering {SCENE_NAME}")
    print(f"  Scene : {SCENE_FILE}")
    print(f"  Output: {run_dir}")
    print(f"  Quality: -q{quality}")
    print("=" * 60)

    cmd = [
        PYTHON_EXE, "-m", "manim",
        str(SCENE_FILE),
        SCENE_NAME,
        f"-q{quality}",
        "--output_file", SCENE_NAME,
        "--media_dir", str(run_dir),
    ]
    print("Running:", " ".join(cmd), "\n")
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))

    if result.returncode == 0:
        mp4_candidates = list(run_dir.rglob("*.mp4"))
        if mp4_candidates:
            latest = OUTPUT_DIR / f"{SCENE_NAME}_latest.mp4"
            import shutil
            shutil.copy2(mp4_candidates[0], latest)
            print(f"\nOK — copied to {latest}")
        else:
            print("\nOK — no mp4 found to copy")
    else:
        print(f"\nFAILED — exit code {result.returncode}")

    return result.returncode


if __name__ == "__main__":
    import sys
    quality = sys.argv[1] if len(sys.argv) > 1 else "h"
    exit(render(quality))
