"""Stick Figure Walking Scene
==============================
The neutral front-facing stick figure turns 90° to the figure's right, then
walks forward 5 paces (moving to screen right).

Animation phases (total: 5.0 s):
  0.00 – 0.30 s   FadeIn  front-facing neutral figure at centre
  0.30 – 0.80 s   Turn    squash + slide left → simulates 90° rightward turn
  0.80 – 1.10 s   Expand  profile figure at walk-start position (x = -2.5)
  1.10 – 4.60 s   Walk    5 strides × 0.70 s, alternating StrideA / StrideB
  4.60 – 5.00 s   Hold

Profile convention (figure facing +x = screen right):
  L_ prefix → "back" limb (extends toward -x while walking)
  R_ prefix → "front" limb (extends toward +x while walking)
  Contralateral gait: StrideA = R-leg forward + L-arm forward;
                      StrideB = L-leg forward + R-arm forward.
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
from Scenes.stick_figure_pirouette_scene import (
    _Neutral,           # original front-view neutral pose
    _build_figure,      # front-view figure builder
    _pt,                # np.array([x, y, 0.0]) shorthand
)

# ---------------------------------------------------------------------------
# Profile-view pose definitions
# All coordinates are at x=0 (figure is built centred at origin, then shifted)
# ---------------------------------------------------------------------------

class _ProfileNeutral:
    """Facing right — natural parallel stance."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.06,  1.68)   # back shoulder
    R_SHOULDER = _pt( 0.08,  1.62)   # front shoulder
    L_ELBOW    = _pt(-0.35,  0.88)   # back arm hangs slightly behind
    R_ELBOW    = _pt( 0.38,  0.88)   # front arm hangs slightly ahead
    L_WRIST    = _pt(-0.48,  0.14)
    R_WRIST    = _pt( 0.50,  0.14)
    L_FINGERS  = [_pt(-0.58,  0.30), _pt(-0.62,  0.12), _pt(-0.58, -0.06)]
    R_FINGERS  = [_pt( 0.60,  0.30), _pt( 0.64,  0.12), _pt( 0.60, -0.06)]
    L_HIP      = _pt(-0.07, -0.35)
    R_HIP      = _pt( 0.09, -0.35)
    L_KNEE     = _pt(-0.14, -1.44)
    R_KNEE     = _pt( 0.16, -1.44)
    L_ANKLE    = _pt(-0.14, -2.52)
    R_ANKLE    = _pt( 0.16, -2.52)
    L_FOOT     = _pt( 0.10, -2.58)   # both feet point forward (right)
    R_FOOT     = _pt( 0.32, -2.58)


class _ProfileStrideA:
    """Stride A: R-leg forward (+x), L-arm forward (+x) — contralateral gait."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.06,  1.68)
    R_SHOULDER = _pt( 0.08,  1.62)
    # L arm swings forward
    L_ELBOW    = _pt( 0.28,  1.06)
    L_WRIST    = _pt( 0.50,  0.38)
    L_FINGERS  = [_pt( 0.60,  0.55), _pt( 0.63,  0.36), _pt( 0.58,  0.20)]
    # R arm swings backward
    R_ELBOW    = _pt(-0.28,  1.06)
    R_WRIST    = _pt(-0.48,  0.38)
    R_FINGERS  = [_pt(-0.56,  0.55), _pt(-0.60,  0.36), _pt(-0.55,  0.20)]
    L_HIP      = _pt(-0.07, -0.35)
    R_HIP      = _pt( 0.09, -0.35)
    # R leg forward (+x)
    R_KNEE     = _pt( 0.52, -1.22)
    R_ANKLE    = _pt( 0.62, -2.28)
    R_FOOT     = _pt( 0.80, -2.55)   # heel contact ahead
    # L leg back (-x)
    L_KNEE     = _pt(-0.40, -1.25)
    L_ANKLE    = _pt(-0.42, -2.40)
    L_FOOT     = _pt(-0.18, -2.55)   # toe-off


class _ProfileStrideB:
    """Stride B: L-leg forward (+x), R-arm forward (+x) — mirror of StrideA."""
    HEAD       = _pt( 0.00,  2.70)
    L_SHOULDER = _pt(-0.06,  1.68)
    R_SHOULDER = _pt( 0.08,  1.62)
    # R arm swings forward
    R_ELBOW    = _pt( 0.28,  1.06)
    R_WRIST    = _pt( 0.50,  0.38)
    R_FINGERS  = [_pt( 0.60,  0.55), _pt( 0.63,  0.36), _pt( 0.58,  0.20)]
    # L arm swings backward
    L_ELBOW    = _pt(-0.28,  1.06)
    L_WRIST    = _pt(-0.48,  0.38)
    L_FINGERS  = [_pt(-0.56,  0.55), _pt(-0.60,  0.36), _pt(-0.55,  0.20)]
    L_HIP      = _pt(-0.07, -0.35)
    R_HIP      = _pt( 0.09, -0.35)
    # L leg forward (+x)
    L_KNEE     = _pt( 0.52, -1.22)
    L_ANKLE    = _pt( 0.62, -2.28)
    L_FOOT     = _pt( 0.80, -2.55)   # heel contact ahead
    # R leg back (-x)
    R_KNEE     = _pt(-0.40, -1.25)
    R_ANKLE    = _pt(-0.42, -2.40)
    R_FOOT     = _pt(-0.18, -2.55)   # toe-off


# ---------------------------------------------------------------------------
# Profile figure builder
# Identical submobject topology to _build_figure() so Transform works between
# any two profile poses:
#   VGroup [5]
#   ├── head    Circle
#   ├── face    VGroup [6]  — l_eye, r_eye, l_brow, r_brow, nose, mouth
#   ├── torso   VGroup [3]  — spine, collar, hip_line
#   ├── arms    VGroup [14] — 2 × (upper, e_dot, forearm, w_dot, f0, f1, f2)
#   └── legs    VGroup [10] — 2 × (thigh, k_dot, shin, a_dot, foot)
# ---------------------------------------------------------------------------

def _build_profile_figure(pose) -> VGroup:
    hc = pose.HEAD
    hx, hy = float(hc[0]), float(hc[1])

    # ── Head ──────────────────────────────────────────────────────────────
    head = Circle(
        radius=_HEAD_RADIUS, color=_BODY_COLOR, stroke_width=_BODY_STROKE,
    ).move_to(hc)

    # ── Face — side view (figure facing +x) ───────────────────────────────
    eye_y   = hy + 0.10
    brow_y  = eye_y + 0.18

    # Near (forward-right) eye — prominent
    r_eye  = Dot(np.array([hx + 0.22, eye_y, 0.0]), radius=0.042, color=_FACE_COLOR)
    # Far (back-left) eye — smaller, partially hidden
    l_eye  = Dot(np.array([hx - 0.06, eye_y, 0.0]), radius=0.022, color=_FACE_COLOR)

    # Forward brow (above near eye)
    r_brow = Line(
        np.array([hx + 0.10, brow_y,        0.0]),
        np.array([hx + 0.34, brow_y + 0.04, 0.0]),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )
    # Back brow — short stub
    l_brow = Line(
        np.array([hx - 0.18, brow_y + 0.02, 0.0]),
        np.array([hx + 0.02, brow_y + 0.02, 0.0]),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )

    # Nose: downward-forward tick pointing right
    nose = Line(
        np.array([hx + _HEAD_RADIUS * 0.72, hy - 0.02, 0.0]),
        np.array([hx + _HEAD_RADIUS + 0.09, hy - 0.10, 0.0]),
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    )

    # Mouth: small smile arc on the forward side of the face
    mouth = Arc(
        radius=0.10, start_angle=PI + PI / 6, angle=2 * PI / 3,
        color=_FACE_COLOR, stroke_width=_FACE_STROKE,
    ).move_arc_center_to(np.array([hx + 0.20, hy - 0.22, 0.0]))

    face = VGroup(l_eye, r_eye, l_brow, r_brow, nose, mouth)

    # ── Torso ─────────────────────────────────────────────────────────────
    chin_y    = hy - _HEAD_RADIUS
    hip_mid_y = float((pose.L_HIP[1] + pose.R_HIP[1]) / 2)

    spine    = Line(np.array([hx, chin_y, 0.0]), np.array([hx, hip_mid_y, 0.0]),
                    color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    collar   = Line(pose.L_SHOULDER, pose.R_SHOULDER,
                    color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    hip_line = Line(pose.L_HIP, pose.R_HIP,
                    color=_BODY_COLOR, stroke_width=_BODY_STROKE)
    torso = VGroup(spine, collar, hip_line)

    # ── Arms (L then R; 7 submobjects each = 14 total) ───────────────────
    arm_parts = []
    for shoulder, elbow, wrist, fingers in (
        (pose.L_SHOULDER, pose.L_ELBOW, pose.L_WRIST, pose.L_FINGERS),
        (pose.R_SHOULDER, pose.R_ELBOW, pose.R_WRIST, pose.R_FINGERS),
    ):
        arm_parts += [
            Line(shoulder, elbow,      color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(elbow),
            Line(elbow,    wrist,      color=_BODY_COLOR, stroke_width=_BODY_STROKE),
            _joint_dot(wrist),
            Line(wrist, fingers[0],    color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
            Line(wrist, fingers[1],    color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
            Line(wrist, fingers[2],    color=_BODY_COLOR, stroke_width=_FINGER_STROKE),
        ]
    arms = VGroup(*arm_parts)

    # ── Legs (L then R; 5 submobjects each = 10 total) ───────────────────
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

class StickFigureWalking(Scene):
    """
    The neutral stick figure turns 90° to figure's right then walks 5 paces.

    Turn is simulated by squashing the front-facing figure to near-zero width
    (figure turns edge-on at the 90° point), removing it, and expanding a
    profile figure from near-zero at the walk start position.

    Walking uses contralateral arm-leg swing (Stride A / B alternating) with
    each stride Transforming the figure to the next pose while advancing +x.

    Total duration: 5.0 s
    """

    WALK_START_X = -2.5
    STRIDE_DIST  = 1.0
    STRIDE_DUR   = 0.70
    FLOOR_Y      = -2.68

    def construct(self):
        self.camera.background_color = "#1a1a1a"

        # Floor line — spans from just before start to just after finish
        floor_start = self.WALK_START_X - 0.5
        floor_end   = self.WALK_START_X + self.STRIDE_DIST * 5 + 0.5  # +3.0
        floor = Line(
            np.array([floor_start, self.FLOOR_Y, 0.0]),
            np.array([floor_end,   self.FLOOR_Y, 0.0]),
            color=GRAY, stroke_width=1.5,
        )
        self.add(floor)

        # ── Phase 0: FadeIn front-facing neutral figure at centre (0.3 s) ──
        front = _build_figure(_Neutral)
        self.play(FadeIn(front, run_time=0.3))

        # ── Phase 1: Turn — squash + slide to walk start (0.5 s) ───────────
        # stretch(0.001, 0): squash X to near-zero (figure turns edge-on)
        # shift LEFT: figure slides to walk-start as it turns
        self.play(
            front.animate
                .stretch(0.001, 0)
                .shift(LEFT * abs(self.WALK_START_X)),
            run_time=0.5,
        )
        self.remove(front)

        # ── Phase 2: Profile figure expands at walk start (0.3 s) ──────────
        profile = _build_profile_figure(_ProfileNeutral)
        profile.shift(RIGHT * self.WALK_START_X)
        profile.save_state()       # save: normal size at WALK_START_X
        profile.stretch(0.001, 0)  # squash: matches end state of front figure
        self.add(profile)
        self.play(Restore(profile), run_time=0.3)

        # ── Phase 3: Walk — 5 strides A B A B A (0.7 s each) ───────────────
        stride_poses = [
            _ProfileStrideA,
            _ProfileStrideB,
            _ProfileStrideA,
            _ProfileStrideB,
            _ProfileStrideA,
        ]
        current_x = self.WALK_START_X
        for pose_cls in stride_poses:
            current_x += self.STRIDE_DIST
            target = _build_profile_figure(pose_cls)
            target.shift(RIGHT * current_x)
            self.play(
                Transform(profile, target),
                run_time=self.STRIDE_DUR,
                rate_func=smooth,
            )

        # ── Phase 4: Hold (0.4 s) ─────────────────────────────────────────
        self.wait(0.4)
