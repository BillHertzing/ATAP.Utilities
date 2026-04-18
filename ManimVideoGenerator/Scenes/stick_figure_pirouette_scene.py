"""Stick Figure Pirouette Scene
================================
5-second ballet pirouette (en Pirouette) animation derived from StickFigureBase.

The figure uses the same structural topology as StickFigureBase so that Manim
Transform can smoothly morph between any two poses.

Animation phases (total: 5.0 s):
  0.0 – 0.3 s  FadeIn neutral stance
  0.3 – 1.0 s  Préparation: arms open to 2nd position, legs to 4th position
  1.0 – 1.7 s  Rise to retiré: working leg lifts to passé, arms gather to 1st
  1.7 – 3.7 s  Pirouette: one full 360° spin (linear, about figure centre)
  3.7 – 4.4 s  Landing: working leg descends, arms open to bras bas
  4.4 – 5.0 s  Finish hold
"""
from manim import *
import numpy as np

from Scenes.stick_figure_base_scene import (
    _HEAD_RADIUS,
    _BODY_STROKE, _FINGER_STROKE, _FACE_STROKE,
    _BODY_COLOR, _JOINT_COLOR, _FACE_COLOR,
    _JOINT_RADIUS,
    _joint_dot,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _pt(x: float, y: float) -> np.ndarray:
    return np.array([x, y, 0.0])


# ---------------------------------------------------------------------------
# Pose definitions  (one class = one keyframe)
# All four poses share the same field names so _build_figure() accepts any of them.
# Head is kept at y=2.70 across all poses so the face sub-objects do not animate.
# ---------------------------------------------------------------------------

class _Neutral:
    """Standing at rest — identical to StickFigureBase layout."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.62,  1.65)
    R_SHOULDER = _pt( 0.62,  1.65)
    L_ELBOW    = _pt(-1.20,  0.85)
    R_ELBOW    = _pt( 1.20,  0.85)
    L_WRIST    = _pt(-1.55,  0.10)
    R_WRIST    = _pt( 1.55,  0.10)
    L_FINGERS  = [_pt(-1.85,  0.38), _pt(-1.97,  0.10), _pt(-1.82, -0.18)]
    R_FINGERS  = [_pt( 1.85,  0.38), _pt( 1.97,  0.10), _pt( 1.82, -0.18)]
    L_HIP      = _pt(-0.30, -0.35)
    R_HIP      = _pt( 0.30, -0.35)
    L_KNEE     = _pt(-0.48, -1.45)
    R_KNEE     = _pt( 0.48, -1.45)
    L_ANKLE    = _pt(-0.48, -2.55)
    R_ANKLE    = _pt( 0.48, -2.55)
    L_FOOT     = _pt(-0.85, -2.55)
    R_FOOT     = _pt( 0.85, -2.55)


class _Prep:
    """Préparation: arms in 2nd position (horizontal, out to sides),
    right leg upright (standing), left leg extended back (4th position)."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.62,  1.65)
    R_SHOULDER = _pt( 0.62,  1.65)
    # Arms: 2nd position — out to sides, slightly below shoulder level
    L_ELBOW    = _pt(-1.30,  1.15)
    R_ELBOW    = _pt( 1.30,  1.15)
    L_WRIST    = _pt(-1.90,  0.90)
    R_WRIST    = _pt( 1.90,  0.90)
    L_FINGERS  = [_pt(-2.12, 1.08), _pt(-2.18, 0.88), _pt(-2.10, 0.68)]
    R_FINGERS  = [_pt( 2.12, 1.08), _pt( 2.18, 0.88), _pt( 2.10, 0.68)]
    L_HIP      = _pt(-0.30, -0.35)
    R_HIP      = _pt( 0.30, -0.35)
    # Right (standing front) leg: straight, slight turnout
    R_KNEE     = _pt( 0.32, -1.42)
    R_ANKLE    = _pt( 0.32, -2.55)
    R_FOOT     = _pt( 0.68, -2.55)
    # Left (back) leg: bent, weight shifted back-left
    L_KNEE     = _pt(-0.62, -1.32)
    L_ANKLE    = _pt(-0.80, -2.48)
    L_FOOT     = _pt(-1.15, -2.48)


class _Retirer:
    """En retiré (pirouette pose):
    - Right leg straight, demi-pointe (ankle raised, toes touching floor).
    - Left leg in retiré/passé: knee out to side, foot folded beside standing knee.
    - Arms in 1st position: rounded oval in front of the body.
    """
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.62,  1.65)
    R_SHOULDER = _pt( 0.62,  1.65)
    # Arms: 1st position — rounded oval, elbows curve inward, hands meet low-front
    L_ELBOW    = _pt(-0.72,  0.82)
    R_ELBOW    = _pt( 0.72,  0.82)
    L_WRIST    = _pt(-0.42,  0.32)
    R_WRIST    = _pt( 0.42,  0.32)
    L_FINGERS  = [_pt(-0.30, 0.14), _pt(-0.20, 0.20), _pt(-0.12, 0.30)]
    R_FINGERS  = [_pt( 0.30, 0.14), _pt( 0.20, 0.20), _pt( 0.12, 0.30)]
    # Hips: weight centred over right leg
    L_HIP      = _pt(-0.22, -0.35)
    R_HIP      = _pt( 0.22, -0.35)
    # Right (standing) leg: knee straight, ankle elevated — demi-pointe
    R_KNEE     = _pt( 0.22, -1.38)
    R_ANKLE    = _pt( 0.22, -2.30)   # elevated — ball of foot
    R_FOOT     = _pt( 0.22, -2.60)   # toes pointing toward floor
    # Left (working) leg: retiré — thigh abducted outward, lower leg folded up
    L_KNEE     = _pt(-0.90, -0.62)   # knee out to side at hip level
    L_ANKLE    = _pt(-0.40, -1.12)   # lower leg folded up
    L_FOOT     = _pt(-0.22, -1.38)   # foot beside standing knee


class _Finish:
    """Finish / landing: arms in bras bas (5th low), feet close together."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.62,  1.65)
    R_SHOULDER = _pt( 0.62,  1.65)
    # Arms: bras bas — hanging forward-oval, wrists slightly in front of thighs
    L_ELBOW    = _pt(-0.82,  0.72)
    R_ELBOW    = _pt( 0.82,  0.72)
    L_WRIST    = _pt(-0.55, -0.05)
    R_WRIST    = _pt( 0.55, -0.05)
    L_FINGERS  = [_pt(-0.65, -0.28), _pt(-0.50, -0.32), _pt(-0.38, -0.22)]
    R_FINGERS  = [_pt( 0.65, -0.28), _pt( 0.50, -0.32), _pt( 0.38, -0.22)]
    L_HIP      = _pt(-0.28, -0.35)
    R_HIP      = _pt( 0.28, -0.35)
    # Legs: close together, slight turnout
    L_KNEE     = _pt(-0.38, -1.45)
    R_KNEE     = _pt( 0.38, -1.45)
    L_ANKLE    = _pt(-0.38, -2.55)
    R_ANKLE    = _pt( 0.38, -2.55)
    L_FOOT     = _pt(-0.75, -2.55)
    R_FOOT     = _pt( 0.75, -2.55)


# ---------------------------------------------------------------------------
# Figure builder — produces identical topology for all poses so that Manim
# Transform interpolates smoothly between any two of them.
#
# Submobject tree (flat children counts, same for every pose):
#   VGroup root [5 children]
#   ├── head          Circle
#   ├── face          VGroup [6]  — l_eye, r_eye, l_brow, r_brow, nose, mouth
#   ├── torso         VGroup [3]  — spine, collar, hip_line
#   ├── arms          VGroup [14] — 2 × (upper, elbow_dot, forearm, wrist_dot, f0, f1, f2)
#   └── legs          VGroup [10] — 2 × (thigh, knee_dot, shin, ankle_dot, foot)
# ---------------------------------------------------------------------------

def _build_figure(pose) -> VGroup:
    hc = pose.HEAD
    hx, hy = float(hc[0]), float(hc[1])

    # ── Head ──────────────────────────────────────────────────────────────
    head = Circle(
        radius=_HEAD_RADIUS, color=_BODY_COLOR, stroke_width=_BODY_STROKE,
    ).move_to(hc)

    # ── Face (positions relative to head centre; same for all poses) ──────
    eye_y    = hy + 0.12
    eye_x    = 0.15
    brow_y   = eye_y + 0.17
    brow_h   = 0.12

    l_eye  = Dot(point=_pt(hx - eye_x, eye_y), radius=0.042, color=_FACE_COLOR)
    r_eye  = Dot(point=_pt(hx + eye_x, eye_y), radius=0.042, color=_FACE_COLOR)
    l_brow = Line(
        _pt(hx - eye_x - brow_h, brow_y - 0.03),
        _pt(hx - eye_x + brow_h, brow_y + 0.05),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )
    r_brow = Line(
        _pt(hx + eye_x - brow_h, brow_y + 0.05),
        _pt(hx + eye_x + brow_h, brow_y - 0.03),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )
    nose = Line(
        _pt(hx, eye_y - 0.06), _pt(hx, eye_y - 0.22),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )
    mouth = Arc(
        radius=0.14, start_angle=PI + PI / 6, angle=2 * PI / 3,
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    ).move_arc_center_to(_pt(hx, hy - 0.18))
    face = VGroup(l_eye, r_eye, l_brow, r_brow, nose, mouth)

    # ── Torso ─────────────────────────────────────────────────────────────
    chin_y    = hy - _HEAD_RADIUS
    hip_mid_y = float((pose.L_HIP[1] + pose.R_HIP[1]) / 2)
    spine    = Line(_pt(hx, chin_y), _pt(hx, hip_mid_y), color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    collar   = Line(pose.L_SHOULDER, pose.R_SHOULDER,     color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    hip_line = Line(pose.L_HIP,      pose.R_HIP,          color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    torso = VGroup(spine, collar, hip_line)

    # ── Arms (L then R; exactly 7 submobjects each = 14 total) ───────────
    arm_parts = []
    for shoulder, elbow, wrist, fingers in (
        (pose.L_SHOULDER, pose.L_ELBOW, pose.L_WRIST, pose.L_FINGERS),
        (pose.R_SHOULDER, pose.R_ELBOW, pose.R_WRIST, pose.R_FINGERS),
    ):
        arm_parts += [
            Line(shoulder, elbow, color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(elbow),
            Line(elbow,    wrist, color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(wrist),
            Line(wrist, fingers[0], color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
            Line(wrist, fingers[1], color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
            Line(wrist, fingers[2], color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
        ]
    arms = VGroup(*arm_parts)

    # ── Legs (L then R; exactly 5 submobjects each = 10 total) ───────────
    leg_parts = []
    for hip, knee, ankle, foot in (
        (pose.L_HIP, pose.L_KNEE, pose.L_ANKLE, pose.L_FOOT),
        (pose.R_HIP, pose.R_KNEE, pose.R_ANKLE, pose.R_FOOT),
    ):
        leg_parts += [
            Line(hip,   knee,  color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(knee),
            Line(knee,  ankle, color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(ankle),
            Line(ankle, foot,  color=_BODY_COLOR, stroke_width=_BODY_STROKE),
        ]
    legs = VGroup(*leg_parts)

    return VGroup(head, face, torso, arms, legs)


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

class StickFigurePirouette(Scene):
    """
    5-second ballet pirouette animation.

    Phases
    ------
    0.0–0.3 s   FadeIn  — neutral stance
    0.3–1.0 s   Transform → préparation (arms 2nd, legs 4th)
    1.0–1.7 s   Transform → retiré (arms 1st, working leg passé, demi-pointe)
    1.7–3.7 s   Rotate 360° (linear) — pirouette spin about figure centre
    3.7–4.4 s   Transform → finish (arms bras bas, feet together)
    4.4–5.0 s   Hold
    """

    def construct(self):
        self.camera.background_color = "#1a1a1a"

        # Pre-build all keyframe figures.
        # All have identical submobject topology so Transform interpolates cleanly.
        neutral = _build_figure(_Neutral)
        prep    = _build_figure(_Prep)
        retirer = _build_figure(_Retirer)
        finish  = _build_figure(_Finish)

        # Phase 0 — FadeIn neutral  (0.3 s)
        self.play(FadeIn(neutral, run_time=0.3))

        # Phase 1 — Préparation  (0.7 s)
        self.play(Transform(neutral, prep, run_time=0.7))

        # Phase 2 — Rise to retiré  (0.7 s)
        self.play(Transform(neutral, retirer, run_time=0.7))

        # Phase 3 — Pirouette: simulate rotation around the vertical (Y) axis  (2.0 s)
        # In 2D, a Y-axis spin is represented by squashing the figure's X width
        # to near-zero (figure is edge-on at the 180° point) then expanding it
        # back to full width (completing the 360°).  Two equal half-spins of 1 s each.
        self.play(neutral.animate.stretch(0.001, 0), run_time=1.0, rate_func=linear)
        self.play(neutral.animate.stretch(1000,   0), run_time=1.0, rate_func=linear)

        # Phase 4 — Landing  (0.7 s)
        self.play(Transform(neutral, finish, run_time=0.7))

        # Phase 5 — Finish hold  (0.6 s)
        self.wait(0.6)
