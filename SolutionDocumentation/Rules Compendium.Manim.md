# Rules Compendium — Manim

This file defines the `ManimScene` RulesKind and its Rule Primitives used within the
`ATAP.Utilities.ManimVideoGenerator` subsystem and the AceCommander bolt-on module.

---

## RRSBS Context

The Rules, Rule Sets, and Build Sets (RRSBS) system models code generation and automation
workflows at a structural level. A **RulesKind** classifies what type of artifact a Rule
produces. A **Rule** is composed from one or more **Rule Primitives**, where each primitive
maps to a named non-terminal in the BNF grammar for that artifact type.

This compendium is the authoritative source for Manim-specific Rule Primitives. The full BNF
from which these primitives are drawn appears in
`_Planning/Explainers/0200-manim-video-generator-overview.md § BNF — Manim Python Scene Grammar`.

---

## RulesKind: `ManimScene`

**Philote ID:** `"b2a7f8c3-4e1d-4a90-8f35-3d9e2b5c7f01"`

A `ManimScene` rule fully specifies a single Manim Python Scene class: its imports, the set of
Mobjects used, the animation sequence, and render configuration. When instantiated by
`ManimRenderExecutor`, it renders to a `<SceneClass>.mp4` file in
`media/videos/<file-stem>/<resolution>/`.

### Key Constraint

All AI-generated code that instantiates a `ManimScene` rule MUST produce output valid under
the `<manim-scene-file>` production in the BNF. `ManimRenderExecutor` validates the generated
script by dry-running the Manim scene class resolution before invoking the render.

---

## Rule Primitives

### `<manim-scene-file>`

**Philote ID:** `"c1f3a8e2-5b7d-4c91-9e23-4f0b8d6a2e35"`

**Description:** The top-level production of a Manim animation file. A well-formed Manim scene
file consists of an import section followed by one or more Scene class definitions.

**BNF:**

```bnf
<manim-scene-file> ::= <import-section> <newline> <scene-class-list>
```

**Inputs:**

| Input            | Type                     | Required | Description                         |
| ---------------- | ------------------------ | -------- | ----------------------------------- |
| `ImportSection`  | `ManimImportSection`     | Yes      | Import declarations                 |
| `SceneClassList` | `IList<ManimSceneClass>` | Yes      | One or more scene class definitions |

**Output:** A Python `.py` source file string conforming to the grammar.

**Attribution:** Manim Community v0.20.x scene authoring conventions.

---

### `<scene-class>`

**Philote ID:** `"d7e4b2c9-6a1f-4d80-be57-8c3a9f1b7e42"`

**Description:** A single Python class that inherits from a Manim base scene class and
implements a `construct(self)` method. This is the primary unit of animation authorship.

**BNF:**

```bnf
<scene-class>       ::= "class" <ws> <identifier> "(" <scene-base-class> "):" <newline>
                         <construct-method>

<scene-base-class>  ::= "Scene"
                       | "ThreeDScene"
                       | "MovingCameraScene"
                       | "ZoomedScene"
                       | "VectorScene"

<construct-method>  ::= <indent> "def construct(self):" <newline> <stmt-list>
```

**Inputs:**

| Input        | Type                    | Required | Description                                          |
| ------------ | ----------------------- | -------- | ---------------------------------------------------- |
| `ClassName`  | `string`                | Yes      | Python identifier; used as the `manim` CLI class arg |
| `BaseClass`  | `ManimSceneBaseClass`   | Yes      | Enum: Scene, ThreeDScene, MovingCameraScene, etc.    |
| `Statements` | `IList<ManimStatement>` | Yes      | Body of the `construct` method                       |

**Output:** A Python class definition string.

**Attribution:** Manim Community scene class pattern.

---

### `<mobject-expr>`

**Philote ID:** `"e9a5c3f1-7b2e-4f92-ad68-5d4c0e8b3f19"`

**Description:** A Mathematical Object (Mobject) expression that produces a displayable Manim
object. Mobjects are the fundamental visual elements of a Manim scene.

**BNF:**

```bnf
<mobject-expr>     ::= <text-mobject>
                     | <math-mobject>
                     | <shape-mobject>
                     | <group-mobject>
                     | <threed-mobject>
                     | <graph-mobject>
                     | <mobject-expr> "." <method-call>

<text-mobject>     ::= "Text(" <string> <text-kwargs>? ")"

<math-mobject>     ::= "MathTex(" <latex-string-list> <kwargs>? ")"
                     | "Tex(" <string> <kwargs>? ")"

<shape-mobject>    ::= "Circle(" <kwargs>? ")"
                     | "Square(" <kwargs>? ")"
                     | "Rectangle(" <kwargs>? ")"
                     | "Line(" <point> "," <point> <kwargs>? ")"
                     | "Arrow(" <point> "," <point> <kwargs>? ")"
                     | "Dot(" <point>? <kwargs>? ")"

<group-mobject>    ::= "VGroup(" <mobject-list> <kwargs>? ")"
                     | "Group(" <mobject-list> <kwargs>? ")"

<threed-mobject>   ::= "Sphere(" <kwargs>? ")"
                     | "ThreeDAxes(" <kwargs>? ")"
                     | "Surface(" <python-lambda-or-id> <kwargs>? ")"

<graph-mobject>    ::= "Axes(" <kwargs>? ")"
                     | "NumberPlane(" <kwargs>? ")"
                     | "FunctionGraph(" <python-lambda-or-id> <kwargs>? ")"
```

**Inputs:**

| Input             | Type                          | Required | Description                                      |
| ----------------- | ----------------------------- | -------- | ------------------------------------------------ |
| `MobjectType`     | `ManimMobjectKind`            | Yes      | Enum discriminator (Text, Math, Shape, 3D, etc.) |
| `ConstructorArgs` | `IList<ManimArg>`             | No       | Positional arguments (e.g. centre point)         |
| `Kwargs`          | `IDictionary<string, string>` | No       | Keyword arguments (color, font_size, etc.)       |

**Output:** A Manim Mobject constructor call expression string.

**Attribution:** Manim Community Mobject class hierarchy.

---

### `<anim-expr>`

**Philote ID:** `"f2b8d6e4-3c9a-4e01-9f74-6e5d1b2a8c37"`

**Description:** An animation expression passed to `self.play(...)`. An animation expression
describes a visual transition applied to one or more Mobjects over a duration.

**BNF:**

```bnf
<anim-expr>        ::= <creation-anim>
                     | <transform-anim>
                     | <indication-anim>
                     | <motion-anim>
                     | <compound-anim>
                     | <method-anim>

<creation-anim>    ::= "Write(" <mobject-ref> <kwargs>? ")"
                     | "Create(" <mobject-ref> <kwargs>? ")"
                     | "FadeIn(" <mobject-ref> <kwargs>? ")"
                     | "FadeOut(" <mobject-ref> <kwargs>? ")"
                     | "GrowFromCenter(" <mobject-ref> <kwargs>? ")"
                     | "ShrinkToCenter(" <mobject-ref> <kwargs>? ")"

<transform-anim>   ::= "Transform(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                     | "ReplacementTransform(" <mobject-ref> "," <mobject-ref-or-expr> <kwargs>? ")"
                     | "MoveToTarget(" <mobject-ref> <kwargs>? ")"

<indication-anim>  ::= "Indicate(" <mobject-ref> <kwargs>? ")"
                     | "Flash(" <mobject-ref> <kwargs>? ")"
                     | "Circumscribe(" <mobject-ref> <kwargs>? ")"
                     | "Wiggle(" <mobject-ref> <kwargs>? ")"

<motion-anim>      ::= "MoveAlongPath(" <mobject-ref> "," <mobject-ref> <kwargs>? ")"
                     | "Rotating(" <mobject-ref> <kwargs>? ")"

<compound-anim>    ::= "AnimationGroup(" <anim-list> <kwargs>? ")"
                     | "Succession(" <anim-list> <kwargs>? ")"
                     | "LaggedStart(" <anim-list> <kwargs>? ")"

<method-anim>      ::= <mobject-ref> ".animate." <method-call>
```

**Inputs:**

| Input           | Type                          | Required | Description                                                     |
| --------------- | ----------------------------- | -------- | --------------------------------------------------------------- |
| `AnimationType` | `ManimAnimationKind`          | Yes      | Enum: Creation, Transform, Indication, Motion, Compound, Method |
| `Targets`       | `IList<string>`               | Yes      | One or more Mobject variable names                              |
| `Kwargs`        | `IDictionary<string, string>` | No       | `run_time`, `rate_func`, `lag_ratio`, etc.                      |

**Output:** An animation expression string suitable for inclusion in a `self.play(...)` call.

**Attribution:** Manim Community Animation class hierarchy.

---

### `<play-stmt>`

**Philote ID:** `"a4d7f1b3-2e9c-4b83-8a56-7c2e4f9d1b08"`

**Description:** A `self.play(...)` call that wraps one or more animation expressions and triggers
a rendered animation frame sequence.

**BNF:**

```bnf
<play-stmt>  ::= <indent> "self.play(" <anim-list> <anim-kwargs>? ")" <newline>

<anim-list>  ::= <anim-expr>
               | <anim-list> "," <anim-expr>

<anim-kwargs>::= <anim-kwarg> | <anim-kwargs> "," <anim-kwarg>

<anim-kwarg> ::= "run_time=" <number>
               | "rate_func=" <rate-func-name>
               | "lag_ratio=" <number>
```

**Inputs:**

| Input        | Type                   | Required | Description                                      |
| ------------ | ---------------------- | -------- | ------------------------------------------------ |
| `Animations` | `IList<ManimAnimExpr>` | Yes      | One or more animation expressions                |
| `RunTime`    | `double?`              | No       | Duration in seconds (default is Manim's default) |
| `RateFunc`   | `ManimRateFunc?`       | No       | Easing function enum                             |
| `LagRatio`   | `double?`              | No       | Stagger factor for compound animations           |

**Output:** A `self.play(...)` statement string.

**Attribution:** Manim Community Scene.play() API.

---

### `<wait-stmt>`

**Philote ID:** `"b6c0e5a8-1d4f-4c72-9e37-3f8b5c7d2a91"`

**Description:** A `self.wait(...)` call that inserts a pause of the given duration into the
animation timeline.

**BNF:**

```bnf
<wait-stmt>  ::= <indent> "self.wait(" <number>? ")" <newline>
```

**Inputs:**

| Input      | Type      | Required | Description                           |
| ---------- | --------- | -------- | ------------------------------------- |
| `Duration` | `double?` | No       | Seconds to wait; defaults to 1 second |

**Output:** A `self.wait(...)` statement string.

**Attribution:** Manim Community Scene.wait() API.

---

### `<mobject-assignment>`

**Philote ID:** `"c8a3d6f2-4e1b-4d93-be48-9a7c2e5f0b14"`

**Description:** A Python variable assignment that binds a Mobject constructor expression to a
local name. The bound name is later referenced in animation expressions and `self.add()` /
`self.remove()` calls.

**BNF:**

```bnf
<mobject-assignment> ::= <indent> <identifier> "=" <mobject-expr> <newline>
```

**Inputs:**

| Input          | Type               | Required | Description                        |
| -------------- | ------------------ | -------- | ---------------------------------- |
| `VariableName` | `string`           | Yes      | Python identifier for the Mobject  |
| `MobjectExpr`  | `ManimMobjectExpr` | Yes      | The Mobject constructor expression |

**Output:** A Python assignment statement string (e.g. `    circle = Circle(color=BLUE)`).

**Attribution:** Standard Python assignment within Manim `construct` method.

---

## Enum Definitions (informative)

The following C# enums are implied by the Rule Primitive inputs above.

```csharp
public enum ManimSceneBaseClass { Scene, ThreeDScene, MovingCameraScene, ZoomedScene, VectorScene }

public enum ManimQuality { Low480p15, Medium720p30, High1080p60, Ultra2160p60 }

public enum ManimMobjectKind
{
    Text, MathTex, Tex, Circle, Square, Rectangle, Triangle, Line, Arrow, Dot,
    Arc, Ellipse, VGroup, Group, Sphere, ThreeDAxes, Surface, Axes, NumberPlane,
    FunctionGraph
}

public enum ManimAnimationKind
{
    Write, Create, FadeIn, FadeOut, DrawBorderThenFill,
    GrowFromCenter, ShrinkToCenter, Uncreate,
    Transform, ReplacementTransform, MoveToTarget, TransformFromCopy,
    Indicate, Flash, Circumscribe, Wiggle,
    MoveAlongPath, Rotating, Rotate,
    AnimationGroup, Succession, LaggedStart,
    MethodAnimate, ApplyMethod
}

public enum ManimRateFunc
{
    Linear, Smooth, RushInto, RushFrom, SlowInto,
    DoubleSmooth, ThereAndBack, ThereAndBackWithPause, RunningStart
}
```

---

## References

- [Manim Community API Reference](https://docs.manim.community/en/stable/reference.html)
- [Manim Community Mobject Gallery](https://docs.manim.community/en/stable/reference/manim.mobject.html)
- `_Planning/Explainers/0200-manim-video-generator-overview.md` — full BNF and 0200 series overview
- `SolutionDocumentation/Rules Compendium.CSharp.md` — C# Rule Primitives (format reference)
