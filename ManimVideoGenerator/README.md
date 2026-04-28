# ManimVideoGenerator

Manim animation scenes for ATAP.Utilities documentation and educational content.
Uses [Manim Community](https://docs.manim.community/) v0.20.1 with a Python 3.11.9 virtual environment.

---

## Prerequisites

- Python 3.11.9 installed via `pyenv-win` or direct installer
- Virtual environment created at `.venv\` (see [Setup](#setup))
- MiKTeX installed (for LaTeX/equation rendering)
- VS Code extension `Rickaym.manim-sideview` installed
- `UserSettings.jsonc` updated with sprint-branch venv paths (see [VS Code Settings](#vs-code-settings))

---

## Setup

If the `.venv` does not exist yet, create and populate it:

```powershell
cd 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\ManimVideoGenerator'
python -m venv .venv
& '.\.venv\Scripts\Activate.ps1'
pip install manim
```

Verify the installation:

```powershell
manim --version        # Manim Community v0.20.1
manim checkhealth      # all checks should pass
```

---

## Project Structure

New scenes follow a two-file pattern:

| File               | Location     | Purpose                                               |
| ------------------ | ------------ | ----------------------------------------------------- |
| `<name>_scene.py`  | `Scenes/`    | Manim `Scene` subclass — drawing/animation logic only |
| `render_<name>.py` | `Renderers/` | Entry-point script that invokes Manim via subprocess  |

### Adding a new scene

1. Create `Scenes/<name>_scene.py` with your `Scene` subclass.
2. Create `Renderers/render_<name>.py` using the template below — note `parents[1]` so `SCRIPT_DIR` resolves to the project root regardless of where the script lives:

```python
#!/usr/bin/env python3
"""Render script for <Name> Scene."""
import subprocess
from datetime import datetime
from pathlib import Path

PYTHON_EXE     = r"C:\Python311\python.exe"
SCRIPT_DIR     = Path(__file__).resolve().parents[1]   # ManimVideoGenerator/
OUTPUT_DIR     = SCRIPT_DIR / "_generated"
SCENE_FILE     = SCRIPT_DIR / "Scenes" / "<name>_scene.py"
SCENE_NAME     = "<SceneClassName>"
RUN_OUTPUT_DIR = OUTPUT_DIR / f"_render_run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def render(quality: str = "h") -> int:
    RUN_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    cmd = [
        PYTHON_EXE, "-m", "manim",
        str(SCENE_FILE), SCENE_NAME,
        f"-q{quality}",
        "--media_dir", str(RUN_OUTPUT_DIR),
    ]
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR))
    return result.returncode

if __name__ == "__main__":
    raise SystemExit(render())
```

---

## Creating a New Scene Project

Manim provides a project scaffolding command. Run it from the root of `ManimVideoGenerator\`.

```powershell
# From ManimVideoGenerator root, with venv active:
manim init project testProject --default
cd testProject
```

This creates:

```path
testProject\
├── main.py          # starter scene
├── manim.cfg        # project-level Manim configuration
└── media\           # render output (gitignored)
```

Open `main.py` to see the starter `CreateCircle` scene, then render it:

```powershell
manim -pql main.py CreateCircle
```

---

## Using the Manim Sideview Extension

The **Manim Sideview** extension (`Rickaym.manim-sideview`) lets you render and preview
animations directly inside VS Code without switching to a terminal.

### One-time configuration

1. Open **Settings** (`Ctrl+,`) and search for `manim sideview`.
2. Set **Manim Sideview: Default Manim Path** to the venv `manim.exe`:
   ```
   C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\ManimVideoGenerator\.venv\Scripts\manim.exe
   ```
   _(This is already set in `SharedVSCode\UserSettings.jsonc` for the sprint branch.)_

### Rendering a scene from VS Code

1. Open a `.py` file containing a `Scene` subclass (e.g. `scenes\testProject\main.py`).
2. Open the Command Palette (`Ctrl+Shift+P`) and run:
   **`Manim Sideview: Run Manim Sideview`**
   — or click the **play button** that appears in the top-right editor toolbar when a Manim file is active.
3. If prompted, select the scene class to render (e.g. `CreateCircle`).
4. The rendered video appears in a **split panel** inside VS Code.

### Sideview quality settings

The extension defaults to low quality (`-ql`) for fast previews. To change quality,
open Settings and adjust **Manim Sideview: Video Quality**:

| Value | Resolution | FPS | Use case               |
| ----- | ---------- | --- | ---------------------- |
| `l`   | 480p       | 15  | Fast preview (default) |
| `m`   | 720p       | 30  | Medium quality         |
| `h`   | 1080p      | 60  | Final render           |
| `k`   | 2160p      | 60  | 4K                     |

---

## CLI Rendering

As an alternative to the extension, render from the terminal with the venv active:

```powershell
& '.\.venv\Scripts\Activate.ps1'

# Low quality preview (fastest)
manim -pql <file.py> <SceneClass>

# High quality production render
manim -phq <file.py> <SceneClass>
```

Output is written to `media\videos\<file>\<resolution>\<SceneClass>.mp4`.

---

## Verification Scenes

Two verification scenes are provided at the root level for pipeline health checks:

| File            | Scene        | Tests                                 |
| --------------- | ------------ | ------------------------------------- |
| `test_manim.py` | `HelloManim` | Text animation (no LaTeX)             |
| `test_latex.py` | `LatexTest`  | MathTex equation rendering via MiKTeX |

```powershell
& '.\.venv\Scripts\Activate.ps1'
manim -pql test_manim.py HelloManim    # §10.6 verification
manim -pql test_latex.py LatexTest     # §10.7 verification
```

---

## VS Code Settings

Both `manim-sideview.defaultManimPath` and `python.defaultInterpreterPath` in
`SharedVSCode\UserSettings.jsonc` must point to the **active worktree's venv**.

**Sprint branch** (current):

```jsonc
"manim-sideview.defaultManimPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities-wt-94-sprint-0004-work-items\\ManimVideoGenerator\\.venv\\Scripts\\manim.exe",
"python.defaultInterpreterPath":   "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities-wt-94-sprint-0004-work-items\\ManimVideoGenerator\\.venv\\Scripts\\python.exe"
```

**Main branch** (revert at sprint-end):

```jsonc
"manim-sideview.defaultManimPath": "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities\\ManimVideoGenerator\\.venv\\Scripts\\manim.exe",
"python.defaultInterpreterPath":   "C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities\\ManimVideoGenerator\\.venv\\Scripts\\python.exe"
```

> **Note:** MiKTeX may warn about running with elevated privileges or pending admin
> update check. These are non-fatal. Run **MiKTeX Console → Check for updates** once
> to clear the update warning.

---

## References

- [Manim Community docs](https://docs.manim.community/)
- [Manim Sideview extension](https://marketplace.visualstudio.com/items?itemName=Rickaym.manim-sideview)
- Explainer 0500 §10.3–§10.7 — New Computer Setup (Manim installation and verification)
