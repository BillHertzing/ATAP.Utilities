#!/usr/bin/env python3
"""
Render script for Wall Clock Animation Scene.
Renders the WallClockSceneHD scene to 1080p @ 60fps MP4 file in _generated/ folder.
"""
import subprocess
import sys
import shutil
from datetime import datetime
from pathlib import Path

# Define paths
SCRIPT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = SCRIPT_DIR / "_generated"
MAIN_PY = SCRIPT_DIR / "main.py"
SCENE_NAME = "WallClockSceneHD"
RUN_OUTPUT_DIR = OUTPUT_DIR / f"_render_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
FINAL_VIDEO = RUN_OUTPUT_DIR / "videos" / "main" / "1080p60" / "wall_clock_animation.mp4"

# Ensure output directory exists
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def render_wall_clock():
    """Render the wall clock animation using manim."""
    print("=" * 70)
    print("Wall Clock Animation Renderer")
    print("=" * 70)
    print(f"Project folder: {SCRIPT_DIR}")
    print(f"Output folder: {RUN_OUTPUT_DIR}")
    print()
    print("Rendering configuration:")
    print("  - Resolution: 1920x1080 (1080p)")
    print("  - Frame rate: 60 fps")
    print("  - Duration: 30 seconds")
    print(f"  - Scene: {SCENE_NAME}")
    print()

    if FINAL_VIDEO.exists():
        FINAL_VIDEO.unlink()

    # Build the manim command
    # Using high quality settings and specifying output directory
    cmd = [
        sys.executable,
        "-m", "manim",
        str(MAIN_PY),
        SCENE_NAME,
        "-p",  # Open player after rendering
        "-o", "wall_clock_animation",  # Output filename
        "--media_dir", str(RUN_OUTPUT_DIR)  # Output directory
    ]

    print(f"Executing: {' '.join(cmd)}")
    print()

    try:
        result = subprocess.run(cmd, cwd=str(SCRIPT_DIR), capture_output=False)

        if result.returncode == 0:
            print()
            print("=" * 70)
            print("✓ Render completed successfully")
            print("=" * 70)

            # Find the output file
            video_files = list(RUN_OUTPUT_DIR.rglob("*.mp4"))
            if video_files:
                output_file = video_files[0]
                print(f"Output file: {output_file}")
                print(f"File size: {output_file.stat().st_size / (1024*1024):.2f} MB")
                print()
                print("Animation details:")
                print("  - Clock face: White face with dark background, scaled to 21.25% of the original")
                print("  - Numerals: Arabic (1-12)")
                print("  - Tick marks: 12 positions")
                print("  - Start time: 8:00 AM with live AM/PM indicator")
                print("  - Hour hand: White, rotates clockwise 2x per phase (96 simulated hours total)")
                print("  - Minute hand: White, rotates clockwise 24x per phase")
                print("  - Second hand: Not included")
                print("  - Calendar: 31-day month view starting on Wednesday, scaled to match the clock height")
                print("  - Layout: Window and calendar/clock unit sit on a wall section with more realistic room spacing")
                print("  - Window: windowToTheOutside is four times the calendar/clock-unit height with living-room curtain styling and animated day/night blue-to-black gradient")
                print("  - Day marks: Days 1-4 crossed after each 24-hour phase")
                print("  - Animation: Fade in, four accelerated 24-hour phases, fade out")
                return True
            else:
                print("Warning: Video file not found in output directory")
                return False
        else:
            print()
            print("=" * 70)
            print("✗ Render failed")
            print("=" * 70)
            return False

    except Exception as e:
        print(f"Error during render: {e}")
        return False

if __name__ == "__main__":
    success = render_wall_clock()
    sys.exit(0 if success else 1)
