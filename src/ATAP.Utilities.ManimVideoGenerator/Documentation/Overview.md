# 0200 — ManimVideoGenerator: Overview and Architecture

> **Moved from `_Planning/Explainers/0200-manim-video-generator-overview.md` on 2026-07-06** (Sprint 0012 Task 12.45.d,
> documentation reorganization per `PlanDocumentationReorganization.md`). Master overview
> for the ManimVideoGenerator subsystem (the former Explainer 0200-series head document);
> see also `SolutionDocumentation/Rules Compendium.Manim.md`.

**Series:** Manim Video Generation (0200–02xx)
**Created:** 2026-04-04
**Audience:** Developers, AI Agents, AceCommander module contributors

---

## Purpose

This document is the entry point for the **0200 series**, which describes the design, current
implementation, and planned evolution of the `ManimVideoGenerator` subsystem.

`ManimVideoGenerator` enables automated production of mathematical and instructional animations
rendered as MP4 video files using the [Manim Community](https://docs.manim.community/) library
(v0.20+). The long-term goal is a voice- and text-driven animation authoring capability integrated
into AceCommander as a bolt-on module.

---

## Series Index

| #    | File                                     | Topic                                                                   | Status         |
| ---- | ---------------------------------------- | ----------------------------------------------------------------------- | -------------- |
| 0200 | `0200-manim-video-generator-overview.md` | This document: architecture, phases, BNF, RulesKind                     | ✅ Sprint 0004 |
| 0201 | _(planned)_                              | C# project structure: `ATAP.Utilities.ManimVideoGenerator`              | 🔲 Future      |
| 0202 | _(planned)_                              | AI agent pipeline: description expansion → code generation → rendering  | 🔲 Future      |
| 0203 | _(planned)_                              | AceCommander bolt-on: voice/text input, UI surface, GAN integration     | 🔲 Future      |
| 0204 | _(planned)_                              | Testing strategy: unit tests for scene templates, render pipeline tests | 🔲 Future      |

---

## Scope

This series covers:

- **Current state (Sprint 0004):** Manual Python scene authoring with the Manim Sideview VS Code
  extension; scenes stored in `ATAP.Utilities/ManimVideoGenerator/`.
- **Phase 1 (next sprint):** C# implementation of an AI-agentic text-to-Manim pipeline modelled on
  [SurajPatel04/manimVideoGenerate](https://github.com/SurajPatel04/manimVideoGenerate), replacing
  the Python/FastAPI/LangGraph backend with C# / .NET 8+ and Microsoft.SemanticKernel.
- **Phase 2 (future):** AceCommander bolt-on with voice/text input, GAN-based iterative scene
  refinement, and agent-authored Python scene commands.

**Explicitly excluded from Phase 1:** Cloud video storage (Supabase), front-end UI, multi-language
LaTeX support.

> **File format note:** Manim renders to `.mp4` (H.264/AAC via ffmpeg), **not** `.mpg`
> (MPEG-1/2). All file references across the codebase should use the `.mp4` extension.

---

## Current State (Sprint 0004)

### File Locations

| Path (relative to ATAP.Utilities repo root) | Description                                                        |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `ManimVideoGenerator/`                      | Root workspace for the Python-based animation pipeline             |
| `ManimVideoGenerator/.venv/`                | Python 3.11.9 virtual environment; Manim Community v0.20.1         |
| `ManimVideoGenerator/.gitignore`            | Ignores `.venv/` and `__pycache__/`; `media/` is tracked           |
| `ManimVideoGenerator/test_manim.py`         | §10.6 verification scene: `HelloManim` (plain text, no LaTeX)      |
| `ManimVideoGenerator/test_latex.py`         | §10.7 verification scene: `LatexTest` (MathTex via MiKTeX)         |
| `ManimVideoGenerator/README.md`             | Developer reference for venv, Sideview extension, project creation |
| `ManimVideoGenerator/scenes/`               | User scene projects created via `manim init project`               |
| `ManimVideoGenerator/media/`                | Rendered MP4 output; tracked in git for cross-project reuse        |

### Toolchain

| Component          | Version / Source                                             |
| ------------------ | ------------------------------------------------------------ |
| Python             | 3.11.9 (via pyenv-win)                                       |
| Manim Community    | v0.20.1 (installed in `.venv` via pip)                       |
| MiKTeX             | Latest (for `MathTex` / LaTeX rendering)                     |
| ffmpeg             | Bundled with Manim                                           |
| Cairo / Pango      | Bundled with Manim                                           |
| VS Code Extension  | `Rickaym.manim-sideview` (manually installed)                |
| UserSettings.jsonc | Sprint-branch paths set in `SharedVSCode/UserSettings.jsonc` |

### Workflow (Current — Manual)

1. Developer opens a `.py` scene file under `ManimVideoGenerator\scenes\<project>\`.
2. Developer runs **Manim Sideview: Run Manim Sideview** from the Command Palette, or executes
   `manim -pql <file.py> <SceneClass>` in the terminal (venv activated).
3. Manim renders the animation to `media/videos/<file>/<resolution>/<SceneClass>.mp4`.
4. Developer reviews the preview in the VS Code side panel or system media player.

### Render Output Path Structure

```text
media/
└── videos/
    └── <python-file-stem>/
        └── <quality-resolution>/
            ├── <SceneClass>.mp4
            └── partial_movie_files/
                └── *.mp4
```

| CLI Flag | Quality Enum   | Resolution | FPS |
| -------- | -------------- | ---------- | --- |
| `-ql`    | `Low480p15`    | 480p       | 15  |
| `-qm`    | `Medium720p30` | 720p       | 30  |
| `-qh`    | `High1080p60`  | 1080p      | 60  |
| `-qk`    | `Ultra2160p60` | 2160p      | 60  |

---

## Phase 1: C# Text-to-Manim Pipeline

Phase 1 implements a C# analogue of the
[SurajPatel04/manimVideoGenerate](https://github.com/SurajPatel04/manimVideoGenerate) pipeline.
The reference project uses Python / FastAPI / LangGraph; the ATAP implementation replaces that with
C# .NET 8+ and Microsoft.SemanticKernel for LLM orchestration.

### Planned C# Project Locations

```text
ATAP.Utilities/src/ATAP.Utilities.ManimVideoGenerator/
ATAP.Utilities/src/ATAP.Utilities.ManimVideoGenerator.Interfaces/
ATAP.Utilities/src/ATAP.Utilities.ManimVideoGenerator.StringConstants/
```

> These projects do **not yet exist** as of Sprint 0004. Creation is tracked in future sprint tasks.

### Two-Stage Pipeline

The reference project uses a two-stage pipeline that is adopted directly into the C# design.

#### Stage 1: Description Generation

| Step | Agent / Actor                | Action                                                                                        |
| ---- | ---------------------------- | --------------------------------------------------------------------------------------------- |
| 1    | User / Voice                 | Provides a short natural-language prompt (e.g. "Show a 3D surface plot of sin(x) \* cos(y)")  |
| 2    | `QueryValidationAgent`       | Checks whether the prompt is feasible as a Manim animation                                    |
| 3    | `DescriptionExpansionAgent`  | Generates a detailed scene-by-scene description from the short prompt                         |
| 4    | `DescriptionRefinementAgent` | Iterative loop (max 3×): rewrites description if validation fails                             |
| 5    | `DescriptionValidationAgent` | Re-checks each refined description for quality and completeness                               |
| 6    | Acceptance / Fail            | Accepted description passed to Stage 2; after 3 failures user is prompted for a clearer input |

#### Stage 2: Manim Code Generation and Rendering

| Step | Agent / Actor         | Action                                                                                             |
| ---- | --------------------- | -------------------------------------------------------------------------------------------------- |
| 1    | `CodeGenerationAgent` | LLM call: translate accepted description → Manim Python script string                              |
| 2    | `CodeValidationAgent` | LLM call: does generated code faithfully implement the description?                                |
| 3    | Refinement loop       | If not, `CodeGenerationAgent` re-generates; max 3 iterations                                       |
| 4    | `ManimRenderExecutor` | Activates venv; invokes `manim` CLI via `Process.Start`/`ProcessStartInfo`; captures stdout/stderr |
| 5    | Output delivery       | Returns local MP4 file path; future Phase 2: upload to storage → shareable link                    |

### C# Agent Interface

Each agent implements `IAnimationAgent` (planned interface in `.Interfaces` project):

```csharp
public interface IAnimationAgent
{
    Task<AgentResult> ExecuteAsync(AgentContext context, CancellationToken cancellationToken = default);
}
```

| Agent Class                  | Responsibility                                                |
| ---------------------------- | ------------------------------------------------------------- |
| `QueryValidationAgent`       | LLM call — is the prompt feasible? Returns `ValidationResult` |
| `DescriptionExpansionAgent`  | LLM call — expand short prompt → detailed scene description   |
| `DescriptionRefinementAgent` | LLM call — improve description; called up to 3×               |
| `DescriptionValidationAgent` | LLM call — does description meet quality gate?                |
| `CodeGenerationAgent`        | LLM call — translate description → Manim Python `string`      |
| `CodeValidationAgent`        | LLM call — does code match description?                       |
| `ManimRenderExecutor`        | Shell — activate venv, invoke `manim` CLI, return MP4 path    |

---

## Phase 2: AceCommander Bolt-on (Future)

Phase 2 integrates `ManimVideoGenerator` as a bolt-on module for AceCommander:

- **Input surface:** Voice (via ATAP.Utilities.VoiceAttack or platform STT) or text chat panel
  in the AceCommander Blazor WASM UI.
- **Edit workflow:** User describes an edit to an existing scene; the pipeline diffs the existing
  Python against the new description and generates an updated script.
- **GAN architecture:** A Generative Adversarial Network (Generator + Discriminator) pair where:
  - The **Generator** produces candidate Manim Python scripts.
  - The **Discriminator** scores visual quality and prompt fidelity.
  - The pipeline iterates until the Discriminator accepts the output or a maximum iteration
    count is reached.
- **Output surface:** Embedded video player in the AceCommander Blazor WASM client.
- **Plugin registration:** The bolt-on registers as an `IPlugin` (see
  `AceCommander.Plugin.Abstractions`).

---

## RulesKind: `ManimScene`

A new `RulesKind` is defined for the RRSBS system to represent Manim animation scene definitions.

**RulesKind Name:** `ManimScene`
**Philote ID:** `"b2a7f8c3-4e1d-4a90-8f35-3d9e2b5c7f01"`

A `ManimScene` rule fully specifies a single Manim Python Scene class: its import dependencies,
the list of Mobjects used, the animation sequence, and render configuration. When instantiated by
`ManimRenderExecutor`, it renders to `<SceneClass>.mp4` in `media/videos/`.

**Inputs to a ManimScene Rule:**

| Input               | Type                        | Description                                                 |
| ------------------- | --------------------------- | ----------------------------------------------------------- |
| `SceneClassName`    | `string`                    | Python class name; must match the `class` declaration       |
| `BaseClass`         | `ManimSceneBaseClass`       | `Scene`, `ThreeDScene`, `MovingCameraScene`, `ZoomedScene`  |
| `MobjectList`       | `IList<ManimMobject>`       | Ordered list of Mobject definitions                         |
| `AnimationSequence` | `IList<ManimAnimationStep>` | Ordered list: `play()`, `wait()`, `add()`, `remove()` calls |
| `RenderQuality`     | `ManimQuality`              | `Low480p15`, `Medium720p30`, `High1080p60`, `Ultra2160p60`  |
| `OutputFileName`    | `string?`                   | Override output base name; defaults to `SceneClassName`     |

The full set of Rule Primitives for `ManimScene` is defined in
[`Rules Compendium.Manim.md`](../ATAP.Utilities/SolutionDocumentation/Rules%20Compendium.Manim.md).

---

## BNF — Manim Python Scene Grammar

The following BNF describes the subset of Python syntax that constitutes a well-formed Manim
scene file as consumed by `ManimRenderExecutor`. AI code generation agents **MUST** produce
output that conforms to this grammar.

```bnf
(* ============================================================
   Manim Scene File Grammar
   Conformance target: Manim Community v0.20.x
   ============================================================ *)

<manim-scene-file>       ::= <import-section> <newline> <scene-class-list>

(* --- Imports ----------------------------------------------- *)

<import-section>         ::= "from manim import *"
                           | <explicit-import-list>

<explicit-import-list>   ::= <import-statement>
                           | <explicit-import-list> <newline> <import-statement>

<import-statement>       ::= "from manim import" <ws> <name-list>
                           | "import manim"
                           | "from manim." <identifier> "import" <ws> <name-list>

(* --- Scene class ------------------------------------------- *)

<scene-class-list>       ::= <scene-class>
                           | <scene-class-list> <newline> <scene-class>

<scene-class>            ::= "class" <ws> <identifier> "(" <scene-base-class> "):" <newline>
                             <construct-method>

<scene-base-class>       ::= "Scene"
                           | "ThreeDScene"
                           | "MovingCameraScene"
                           | "ZoomedScene"
                           | "VectorScene"

<construct-method>       ::= <indent> "def construct(self):" <newline> <stmt-list>

(* --- Statements -------------------------------------------- *)

<stmt-list>              ::= <stmt>
                           | <stmt-list> <stmt>

<stmt>                   ::= <mobject-assignment>
                           | <play-stmt>
                           | <wait-stmt>
                           | <add-stmt>
                           | <remove-stmt>
                           | <camera-stmt>
                           | <comment-stmt>
                           | <for-loop>
                           | <generic-python-stmt>

(* --- Mobject Assignment ------------------------------------ *)

<mobject-assignment>     ::= <indent> <identifier> "=" <mobject-expr> <newline>

<mobject-expr>           ::= <text-mobject>
                           | <math-mobject>
                           | <shape-mobject>
                           | <group-mobject>
                           | <threed-mobject>
                           | <graph-mobject>
                           | <mobject-expr> "." <method-call>

(* Text *)

<text-mobject>           ::= "Text(" <string> <text-kwargs>? ")"

<text-kwargs>            ::= <text-kwarg>
                           | <text-kwargs> "," <text-kwarg>

<text-kwarg>             ::= "font_size=" <number>
                           | "color=" <color-value>
                           | "font=" <string>
                           | "weight=" <string>
                           | "line_spacing=" <number>
                           | "t2c=" <python-dict>

(* Math / LaTeX *)

<math-mobject>           ::= "MathTex(" <latex-string-list> <kwargs>? ")"
                           | "Tex(" <string> <kwargs>? ")"
                           | "BulletedList(" <string-list> <kwargs>? ")"
                           | "Title(" <string> <kwargs>? ")"

<latex-string>           ::= <r-string> | <string>
<latex-string-list>      ::= <latex-string>
                           | <latex-string-list> "," <latex-string>

(* Shapes *)

<shape-mobject>          ::= "Circle(" <kwargs>? ")"
                           | "Square(" <kwargs>? ")"
                           | "Rectangle(" <kwargs>? ")"
                           | "Triangle(" <kwargs>? ")"
                           | "RegularPolygon(" <integer> <kwargs>? ")"
                           | "Polygon(" <point-list> <kwargs>? ")"
                           | "Line(" <point> "," <point> <kwargs>? ")"
                           | "Arrow(" <point> "," <point> <kwargs>? ")"
                           | "DoubleArrow(" <point> "," <point> <kwargs>? ")"
                           | "Dot(" <point>? <kwargs>? ")"
                           | "Cross(" <kwargs>? ")"
                           | "Arc(" <kwargs>? ")"
                           | "ArcBetweenPoints(" <point> "," <point> <kwargs>? ")"
                           | "Ellipse(" <kwargs>? ")"
                           | "Annulus(" <kwargs>? ")"
                           | "Brace(" <mobject-ref> <direction-kwarg>? <kwargs>? ")"
                           | "SurroundingRectangle(" <mobject-ref> <kwargs>? ")"
                           | "Underline(" <mobject-ref> <kwargs>? ")"

(* Groups *)

<group-mobject>          ::= "VGroup(" <mobject-list> <kwargs>? ")"
                           | "HGroup(" <mobject-list> <kwargs>? ")"
                           | "Group(" <mobject-list> <kwargs>? ")"

(* 3D Mobjects *)

<threed-mobject>         ::= "Sphere(" <kwargs>? ")"
                           | "Cube(" <kwargs>? ")"
                           | "Cylinder(" <kwargs>? ")"
                           | "Cone(" <kwargs>? ")"
                           | "Torus(" <kwargs>? ")"
                           | "ThreeDAxes(" <kwargs>? ")"
                           | "Surface(" <python-lambda-or-id> <kwargs>? ")"
                           | "ParametricSurface(" <python-lambda-or-id> <kwargs>? ")"

(* Graphs / Axes *)

<graph-mobject>          ::= "Axes(" <kwargs>? ")"
                           | "NumberPlane(" <kwargs>? ")"
                           | "NumberLine(" <kwargs>? ")"
                           | "FunctionGraph(" <python-lambda-or-id> <kwargs>? ")"
                           | "ParametricFunction(" <python-lambda-or-id> <kwargs>? ")"
                           | "ImplicitFunction(" <python-lambda-or-id> <kwargs>? ")"

(* --- Animation Statements ---------------------------------- *)

<play-stmt>              ::= <indent> "self.play(" <anim-list> <anim-kwargs>? ")" <newline>

<anim-list>              ::= <anim-expr>
                           | <anim-list> "," <anim-expr>

<anim-expr>              ::= <creation-anim>
                           | <transform-anim>
                           | <indication-anim>
                           | <motion-anim>
                           | <compound-anim>
                           | <method-anim>

<creation-anim>          ::= "Write(" <mobject-ref> <kwargs>? ")"
                           | "Create(" <mobject-ref> <kwargs>? ")"
                           | "DrawBorderThenFill(" <mobject-ref> <kwargs>? ")"
                           | "FadeIn(" <mobject-ref> <kwargs>? ")"
                           | "FadeOut(" <mobject-ref> <kwargs>? ")"
                           | "GrowFromCenter(" <mobject-ref> <kwargs>? ")"
                           | "GrowFromEdge(" <mobject-ref> "," <direction> <kwargs>? ")"
                           | "SpinInFromNothing(" <mobject-ref> <kwargs>? ")"
                           | "ShrinkToCenter(" <mobject-ref> <kwargs>? ")"
                           | "Uncreate(" <mobject-ref> <kwargs>? ")"
                           | "Unwrite(" <mobject-ref> <kwargs>? ")"

<transform-anim>         ::= "Transform(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                           | "ReplacementTransform(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                           | "TransformFromCopy(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                           | "ClockwiseTransform(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                           | "MoveToTarget(" <mobject-ref> <kwargs>? ")"
                           | "ApplyMatrix(" <matrix-expr> "," <mobject-ref> <kwargs>? ")"
                           | "ApplyFunction(" <python-lambda-or-id> "," <mobject-ref> <kwargs>? ")"

<indication-anim>        ::= "Indicate(" <mobject-ref> <kwargs>? ")"
                           | "Flash(" <mobject-ref> <kwargs>? ")"
                           | "Circumscribe(" <mobject-ref> <kwargs>? ")"
                           | "ShowPassingFlash(" <mobject-ref> <kwargs>? ")"
                           | "Wiggle(" <mobject-ref> <kwargs>? ")"
                           | "ApplyWave(" <mobject-ref> <kwargs>? ")"
                           | "Blink(" <mobject-ref> <kwargs>? ")"

<motion-anim>            ::= "MoveAlongPath(" <mobject-ref> "," <mobject-ref> <kwargs>? ")"
                           | "Rotating(" <mobject-ref> <kwargs>? ")"
                           | "Rotate(" <mobject-ref> "," <angle-expr> <kwargs>? ")"
                           | "Homotopy(" <python-lambda-or-id> "," <mobject-ref> <kwargs>? ")"

<compound-anim>          ::= "AnimationGroup(" <anim-list> <kwargs>? ")"
                           | "Succession(" <anim-list> <kwargs>? ")"
                           | "LaggedStart(" <anim-list> <kwargs>? ")"
                           | "LaggedStartMap(" <anim-class-name> "," <mobject-ref> <kwargs>? ")"

<method-anim>            ::= "ApplyMethod(" <method-ref> <arg-list>? <kwargs>? ")"
                           | <mobject-ref> ".animate." <method-call>

<anim-kwargs>            ::= <anim-kwarg>
                           | <anim-kwargs> "," <anim-kwarg>

<anim-kwarg>             ::= "run_time=" <number>
                           | "rate_func=" <rate-func-name>
                           | "lag_ratio=" <number>

<rate-func-name>         ::= "linear" | "smooth" | "rush_into" | "rush_from"
                           | "slow_into" | "double_smooth" | "there_and_back"
                           | "there_and_back_with_pause" | "running_start"

(* --- Wait / Add / Remove ----------------------------------- *)

<wait-stmt>              ::= <indent> "self.wait(" <number>? ")" <newline>

<add-stmt>               ::= <indent> "self.add(" <mobject-ref-list> ")" <newline>

<remove-stmt>            ::= <indent> "self.remove(" <mobject-ref-list> ")" <newline>

(* --- Camera ----------------------------------------------- *)

<camera-stmt>            ::= <indent> "self.camera." <camera-method-call> <newline>
                           | <indent> "self.move_camera(" <camera-kwargs> ")" <newline>

<camera-method-call>     ::= "set_background_color(" <color-value> ")"
                           | "set_zoom(" <number> ")"

<camera-kwargs>          ::= <camera-kwarg>
                           | <camera-kwargs> "," <camera-kwarg>

<camera-kwarg>           ::= "phi=" <angle-expr>
                           | "theta=" <angle-expr>
                           | "gamma=" <angle-expr>
                           | "zoom=" <number>
                           | "frame_center=" <mobject-ref>

(* --- Shared Terminals ------------------------------------- *)

<kwargs>                 ::= <kwarg> | <kwargs> "," <kwarg>

<kwarg>                  ::= <identifier> "=" <expr>

<mobject-ref>            ::= <identifier>
<mobject-ref-or-expr>    ::= <mobject-ref> | <mobject-expr>
<mobject-list>           ::= <mobject-expr> | <mobject-list> "," <mobject-expr>
<mobject-ref-list>       ::= <mobject-ref> | <mobject-ref-list> "," <mobject-ref>

<color-value>            ::= "WHITE" | "BLACK" | "RED" | "GREEN" | "BLUE"
                           | "YELLOW" | "ORANGE" | "PURPLE" | "PINK"
                           | "GOLD" | "GREY" | "DARK_BLUE" | "LIGHT_BLUE"
                           | "TEAL" | "MAROON" | "LIGHT_GREY" | "DARK_GREY"
                           | <hex-color-string>

<hex-color-string>       ::= '"#' <hex-digit> <hex-digit> <hex-digit>
                                   <hex-digit> <hex-digit> <hex-digit> '"'

<direction>              ::= "UP" | "DOWN" | "LEFT" | "RIGHT"
                           | "UL" | "UR" | "DL" | "DR" | "ORIGIN"
                           | "IN" | "OUT"

<direction-kwarg>        ::= "direction=" <direction>

<point>                  ::= <direction>
                           | "np.array([" <number> "," <number> "," <number> "])"
                           | <identifier>

<point-list>             ::= <point> | <point-list> "," <point>

<angle-expr>             ::= <number>
                           | <number> "*" "DEGREES"
                           | <number> "*" "PI"
                           | "PI" | "TAU" | "DEGREES"

<anim-class-name>        ::= <identifier>

<name-list>              ::= <identifier> | <name-list> "," <identifier>

<string-list>            ::= <string> | <string-list> "," <string>

<r-string>               ::= 'r"' <char>* '"' | "r'" <char>* "'"

<string>                 ::= '"' <char>* '"' | "'" <char>* "'"

<identifier>             ::= <letter> (<letter> | <digit> | "_")*

<number>                 ::= <integer> | <float>

<integer>                ::= <digit>+

<float>                  ::= <digit>+ "." <digit>*

<indent>                 ::= "    " | "\t"

<newline>                ::= "\n" | "\r\n"
```

---

## References

- [Manim Community documentation](https://docs.manim.community/)
- [SurajPatel04/manimVideoGenerate](https://github.com/SurajPatel04/manimVideoGenerate) —
  reference Python/FastAPI/LangGraph pipeline (architecture basis for Phase 1)
- [Manim Sideview extension (Marketplace)](https://marketplace.visualstudio.com/items?itemName=Rickaym.manim-sideview)
- `ATAP.Utilities/SolutionDocumentation/NewComputerSetup.md` → "(Optional) Manim Community
  Animation Tooling" — ManimVideoGenerator installation & verification on a new machine
  (superseded `Explainers/0500-New Computer setup.md` §10.3–§10.7, now in `_Planning/Archived/`)
- `ATAP.Utilities/SolutionDocumentation/Rules Compendium.Manim.md` — full `ManimScene` RulesKind
  and Rule Primitive definitions
- `ATAP.Utilities/ManimVideoGenerator/README.md` — developer reference for current Python workflow
