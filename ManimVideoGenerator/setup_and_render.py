#!/usr/bin/env python3
"""
Wall Clock Animation - Environment Setup and Render Script
Sets up all dependencies and renders the WallClockSceneHD animation.
"""
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.absolute()
OUTPUT_DIR = SCRIPT_DIR / "_generated"


def install_dependencies():
    """Install all required dependencies for manim."""
    print("Installing build tools and dependencies...")

    # Try to install manim with pre-built wheels only
    cmd = [
        sys.executable, "-m", "pip", "install",
        "--only-binary", ":all:",
        "manim[webgl]",  # webgl backend requires fewer build deps
        "-q"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print("Warning: Some build dependencies may be missing.")
        print("To resolve, install Microsoft C++ Build Tools from:")
        print("https://visualstudio.microsoft.com/visual-cpp-build-tools/")
        print()
        print("Error details:")
        print(result.stderr)
        return False

    return True


def render_animation():
    """Render the wall clock animation using manim."""
    print("=" * 70)
    print("Wall Clock Animation Renderer")
    print("=" * 70)
    print()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    cmd = [
        sys.executable, "-m", "manim",
        str(SCRIPT_DIR / "main.py"),
        "WallClockSceneHD",
        "-o", "wall_clock_animation",
        "--media_dir", str(OUTPUT_DIR)
    ]

    print(f"Rendering: {' '.join(cmd)}")
    print()

    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))
    return result.returncode == 0


def validate_output():
    """Validate the rendered animation."""
    video_files = list(OUTPUT_DIR.rglob("*.mp4"))

    if not video_files:
        print("No video files found")
        return False

    output_file = video_files[0]
    file_size_mb = output_file.stat().st_size / (1024 * 1024)

    print()
    print("✓ Animation rendered successfully!")
    print(f"Output file: {output_file}")
    print(f"File size: {file_size_mb:.2f} MB")

    return True


if __name__ == "__main__":
    print("Step 1: Installing dependencies...")
    if not install_dependencies():
        print("\nNote: Install Microsoft C++ Build Tools to complete setup")
        sys.exit(1)

    print("Step 2: Rendering animation...")
    if not render_animation():
        print("\nRender failed")
        sys.exit(1)

    print("Step 3: Validating output...")
    if not validate_output():
        sys.exit(1)

    print("\nDone!")
