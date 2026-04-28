"""Stick Figure Base Scene
=======================
A single minimalist stick figure with:
  - Head: eyes, eyebrows, nose, mouth (minimalist)
  - Arms: upper arm ▸ elbow joint ▸ forearm ▸ wrist joint ▸ hand (3 fingers)
  - Legs: thigh ▸ knee joint ▸ shin ▸ ankle joint ▸ foot

Place in: ManimVideoGenerator/Scenes/stick_figure_base_scene.py
"""
from manim import *
import numpy as np

# ---------------------------------------------------------------------------
# Layout constants  (Manim scene units; frame is approx 14 wide × 8 tall)
# ---------------------------------------------------------------------------

# Head
_HEAD_CENTER   = np.array([ 0.00,  2.70,  0.0])
_HEAD_RADIUS   = 0.45

# Arms
_L_SHOULDER    = np.array([-0.62,  1.65,  0.0])
_R_SHOULDER    = np.array([ 0.62,  1.65,  0.0])

_L_ELBOW       = np.array([-1.20,  0.85,  0.0])
_R_ELBOW       = np.array([ 1.20,  0.85,  0.0])

_L_WRIST       = np.array([-1.55,  0.10,  0.0])
_R_WRIST       = np.array([ 1.55,  0.10,  0.0])

# Fingers: 3 per hand, fanned from wrist (index / middle / ring)
_L_FINGER_TIPS = [
    np.array([-1.85,  0.38,  0.0]),   # index  — upper
    np.array([-1.97,  0.10,  0.0]),   # middle — centre
    np.array([-1.82, -0.18,  0.0]),   # ring   — lower
]
_R_FINGER_TIPS = [
    np.array([ 1.85,  0.38,  0.0]),
    np.array([ 1.97,  0.10,  0.0]),
    np.array([ 1.82, -0.18,  0.0]),
]

# Pelvis / hip attachment points
_L_HIP         = np.array([-0.30, -0.35,  0.0])
_R_HIP         = np.array([ 0.30, -0.35,  0.0])

# Legs
_L_KNEE        = np.array([-0.48, -1.45,  0.0])
_R_KNEE        = np.array([ 0.48, -1.45,  0.0])

_L_ANKLE       = np.array([-0.48, -2.55,  0.0])
_R_ANKLE       = np.array([ 0.48, -2.55,  0.0])

# Feet (short horizontal line extending from ankle)
_L_FOOT_TIP    = np.array([-0.85, -2.55,  0.0])
_R_FOOT_TIP    = np.array([ 0.85, -2.55,  0.0])

# ---------------------------------------------------------------------------
# Style
# ---------------------------------------------------------------------------
_BODY_STROKE    = 3
_FINGER_STROKE  = 2
_FACE_STROKE    = 2
_JOINT_RADIUS   = 0.07

_BODY_COLOR     = WHITE
_JOINT_COLOR    = YELLOW
_FACE_COLOR     = WHITE

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _joint_dot(pos: np.ndarray) -> Dot:
    """Return a small highlighted dot marking an articulation joint."""
    return Dot(point=pos, radius=_JOINT_RADIUS, color=_JOINT_COLOR)


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

class StickFigureBase(Scene):
    """
    Static scene: a single stick figure that fades in over 1 second and
    holds for 2 seconds.

    The figure features:
    - Minimalist face (outline head, dot eyes, angled brows, tick nose, arc mouth)
    - Shoulder crossbar + spine + hip crossbar for torso
    - Both arms with elbow and wrist joints; three fingers each hand
    - Both legs with knee and ankle joints; short horizontal foot
    - Yellow joint dots at all articulation points (elbows, wrists, knees, ankles)
    """

    def construct(self):
        self.camera.background_color = "#1a1a1a"
        figure = self._build_figure()
        self.play(FadeIn(figure, run_time=1.0))
        self.wait(2)

    # ------------------------------------------------------------------
    # Top-level builder
    # ------------------------------------------------------------------

    def _build_figure(self) -> VGroup:
        return VGroup(
            self._head(),
            self._face(),
            self._torso(),
            self._arms(),
            self._legs(),
        )

    # ------------------------------------------------------------------
    # Head
    # ------------------------------------------------------------------

    def _head(self) -> Circle:
        return Circle(
            radius=_HEAD_RADIUS,
            color=_BODY_COLOR,
            stroke_width=_BODY_STROKE,
        ).move_to(_HEAD_CENTER)

    # ------------------------------------------------------------------
    # Face – minimalist
    # ------------------------------------------------------------------

    def _face(self) -> VGroup:
        hx, hy = float(_HEAD_CENTER[0]), float(_HEAD_CENTER[1])

        # --- Eyes: small filled dots ---
        eye_y    =  hy + 0.12
        eye_x    =  0.15
        l_eye = Dot(point=np.array([-eye_x, eye_y, 0.0]), radius=0.042, color=_FACE_COLOR)
        r_eye = Dot(point=np.array([ eye_x, eye_y, 0.0]), radius=0.042, color=_FACE_COLOR)

        # --- Eyebrows: angled short lines above each eye ---
        brow_y    = eye_y + 0.17
        brow_half = 0.12
        # Left brow: inner end higher (raised inner corner = neutral/mild expression)
        l_brow = Line(
            start=np.array([-eye_x - brow_half, brow_y - 0.03, 0.0]),
            end  =np.array([-eye_x + brow_half, brow_y + 0.05, 0.0]),
            color=_FACE_COLOR, stroke_width=_FACE_STROKE,
        )
        # Right brow: mirror
        r_brow = Line(
            start=np.array([ eye_x - brow_half, brow_y + 0.05, 0.0]),
            end  =np.array([ eye_x + brow_half, brow_y - 0.03, 0.0]),
            color=_FACE_COLOR, stroke_width=_FACE_STROKE,
        )

        # --- Nose: short vertical tick below eye centre ---
        nose_top = np.array([hx, eye_y - 0.06, 0.0])
        nose_tip = np.array([hx, eye_y - 0.22, 0.0])
        nose = Line(start=nose_top, end=nose_tip, color=_FACE_COLOR, stroke_width=_FACE_STROKE)

        # --- Mouth: concave-up arc (smile) ---
        # Arc goes from 210° to 330° counter-clockwise (sweeps through 270° at bottom).
        # Arc center is placed so the lowest point of the arc sits at approx hy - 0.32.
        mouth_arc_center = np.array([hx, hy - 0.18, 0.0])
        mouth = Arc(
            radius=0.14,
            start_angle=PI + PI / 6,    # 210°
            angle=2 * PI / 3,           # +120° → ends at 330°
            color=_FACE_COLOR,
            stroke_width=_FACE_STROKE,
        ).move_arc_center_to(mouth_arc_center)

        return VGroup(l_eye, r_eye, l_brow, r_brow, nose, mouth)

    # ------------------------------------------------------------------
    # Torso: spine + shoulder crossbar + hip crossbar
    # ------------------------------------------------------------------

    def _torso(self) -> VGroup:
        chin_y = float(_HEAD_CENTER[1]) - _HEAD_RADIUS   # bottom of head circle
        hx     = float(_HEAD_CENTER[0])
        hip_y  = float((_L_HIP[1] + _R_HIP[1]) / 2)

        spine = Line(
            start=np.array([hx, chin_y, 0.0]),
            end  =np.array([hx, hip_y,  0.0]),
            color=_BODY_COLOR, stroke_width=_BODY_STROKE,
        )
        collar = Line(
            start=_L_SHOULDER, end=_R_SHOULDER,
            color=_BODY_COLOR, stroke_width=_BODY_STROKE,
        )
        hip_line = Line(
            start=_L_HIP, end=_R_HIP,
            color=_BODY_COLOR, stroke_width=_BODY_STROKE,
        )
        return VGroup(spine, collar, hip_line)

    # ------------------------------------------------------------------
    # Arms: upper arm → elbow joint → forearm → wrist joint → 3 fingers
    # ------------------------------------------------------------------

    def _arms(self) -> VGroup:
        parts = []
        for shoulder, elbow, wrist, finger_tips in (
            (_L_SHOULDER, _L_ELBOW, _L_WRIST, _L_FINGER_TIPS),
            (_R_SHOULDER, _R_ELBOW, _R_WRIST, _R_FINGER_TIPS),
        ):
            parts.append(Line(start=shoulder, end=elbow,
                               color=_BODY_COLOR, stroke_width=_BODY_STROKE))
            parts.append(_joint_dot(elbow))
            parts.append(Line(start=elbow, end=wrist,
                               color=_BODY_COLOR, stroke_width=_BODY_STROKE))
            parts.append(_joint_dot(wrist))
            for tip in finger_tips:
                parts.append(Line(start=wrist, end=tip,
                                   color=_BODY_COLOR, stroke_width=_FINGER_STROKE))
        return VGroup(*parts)

    # ------------------------------------------------------------------
    # Legs: thigh → knee joint → shin → ankle joint → foot
    # ------------------------------------------------------------------

    def _legs(self) -> VGroup:
        parts = []
        for hip, knee, ankle, foot_tip in (
            (_L_HIP, _L_KNEE, _L_ANKLE, _L_FOOT_TIP),
            (_R_HIP, _R_KNEE, _R_ANKLE, _R_FOOT_TIP),
        ):
            parts.append(Line(start=hip,   end=knee,
                               color=_BODY_COLOR, stroke_width=_BODY_STROKE))
            parts.append(_joint_dot(knee))
            parts.append(Line(start=knee,  end=ankle,
                               color=_BODY_COLOR, stroke_width=_BODY_STROKE))
            parts.append(_joint_dot(ankle))
            parts.append(Line(start=ankle, end=foot_tip,
                               color=_BODY_COLOR, stroke_width=_BODY_STROKE))
        return VGroup(*parts)
