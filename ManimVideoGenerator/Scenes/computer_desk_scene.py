"""Computer Desk Scene
======================
A pseudo-3D view of a computer workstation from a few feet away.

Viewport convention (Manim default): x in [-7.1, 7.1], y in [-4.0, 4.0]

Layout anchors:
  Floor line  : y = -3.50
  Desk surface: y =  0.30   (front edge of tabletop)
  Desk top (back edge): y = 0.70   (higher → depth illusion trapezoid)

Elements and their approximate positions:
  Desk tabletop  : Polygon trapezoid — back y=0.70 x=[-3.2,3.2],
                                        front y=0.30 x=[-3.5,3.5]
  Desk front face: Rectangle   x=[-3.5,3.5], y=[-1.40, 0.30]
  Desk left leg  : Rectangle   x=[-3.3,-2.9], y=[-3.50,-1.40]
  Desk right leg : Rectangle   x=[ 2.9, 3.3], y=[-3.50,-1.40]

  Monitor bezel  : Rectangle   x=[-1.20, 1.20], y=[ 0.70, 2.90]
                   (sits on desk surface, bottom of bezel at y=0.70)
  Monitor screen : Rectangle   x=[-1.08, 1.08], y=[ 0.82, 2.78]  (inset)
  Monitor stand  : Rectangle   x=[-0.12, 0.12], y=[ 0.30, 0.70]
  Stand base     : Rectangle   x=[-0.35, 0.35], y=[ 0.28, 0.38]

  Keyboard       : Rectangle   x=[-0.75, 0.75], y=[ 0.34, 0.54]
                   (on desk surface, slightly in front of monitor stand)

  Chair seat     : Polygon (slight trapezoid for depth) —
                   back y=-1.10 x=[-0.60,0.60], front y=-1.30 x=[-0.70,0.70]
  Chair back     : Rectangle   x=[-0.55, 0.55], y=[-1.10, 0.15]
  Chair left leg : Line from (-0.65,-1.30) to (-0.60,-3.30)
  Chair right leg: Line from ( 0.65,-1.30) to ( 0.60,-3.30)
  Chair back-left leg: Line from (-0.50,-1.10) to (-0.55,-3.10)
  Chair back-right leg: Line from (0.50,-1.10) to ( 0.55,-3.10)

Animation phases:
  0.0 – 0.5 s   FadeIn desk
  0.5 – 0.9 s   FadeIn monitor (bezel + screen + stand)
  0.9 – 1.2 s   FadeIn keyboard
  1.2 – 1.8 s   FadeIn chair
  1.8 – 3.0 s   Screen glow pulse (screen colour fades in/out gently)
  3.0 – 4.0 s   Hold
"""
from manim import *
import numpy as np

# ---------------------------------------------------------------------------
# Colour constants
# ---------------------------------------------------------------------------
DESK_COLOR      = "#8B5E3C"   # warm wood brown
DESK_FACE_COLOR = "#7A5230"   # slightly darker front face
LEG_COLOR       = "#6B4226"   # darkest wood
MONITOR_BEZEL   = "#2A2A2A"   # near-black plastic
SCREEN_OFF      = "#0D1117"   # near-black screen
SCREEN_ON       = "#1E90FF"   # blue screen glow
KB_COLOR        = "#3C3C3C"   # dark grey keyboard
CHAIR_SEAT      = "#1A3A5C"   # dark blue fabric
CHAIR_FRAME     = "#555555"   # metal grey legs/back frame
FLOOR_COLOR     = "#888888"   # neutral floor line

# ---------------------------------------------------------------------------
# Helper: numpy 3-vector
# ---------------------------------------------------------------------------
def _pt(x: float, y: float) -> np.ndarray:
    return np.array([x, y, 0.0])


# ---------------------------------------------------------------------------
# Builder functions
# ---------------------------------------------------------------------------

def _build_desk() -> VGroup:
    """Return the full desk assembly as a VGroup."""
    # Tabletop — trapezoid (back edge slightly narrower = depth illusion)
    tabletop = Polygon(
        _pt(-3.2,  0.70),  # back-left
        _pt( 3.2,  0.70),  # back-right
        _pt( 3.5,  0.30),  # front-right
        _pt(-3.5,  0.30),  # front-left
        color=DESK_COLOR, fill_color=DESK_COLOR, fill_opacity=1.0,
        stroke_width=1.5,
    )
    # Front face of desk body
    front_face = Rectangle(
        width=7.0, height=1.70,
        color=DESK_FACE_COLOR, fill_color=DESK_FACE_COLOR, fill_opacity=1.0,
        stroke_width=1.5,
    ).move_to(_pt(0.0, -0.55))   # centre between y=0.30 and y=-1.40

    # Left leg
    left_leg = Rectangle(
        width=0.40, height=2.10,
        color=LEG_COLOR, fill_color=LEG_COLOR, fill_opacity=1.0,
        stroke_width=1.5,
    ).move_to(_pt(-3.10, -2.45))  # centre at x=-3.10, y midpoint of [-3.50,-1.40]

    # Right leg
    right_leg = Rectangle(
        width=0.40, height=2.10,
        color=LEG_COLOR, fill_color=LEG_COLOR, fill_opacity=1.0,
        stroke_width=1.5,
    ).move_to(_pt(3.10, -2.45))

    return VGroup(front_face, tabletop, left_leg, right_leg)


def _build_monitor() -> VGroup:
    """Return monitor assembly: bezel + screen + stand + base."""
    bezel = Rectangle(
        width=2.40, height=2.20,
        color=MONITOR_BEZEL, fill_color=MONITOR_BEZEL, fill_opacity=1.0,
        stroke_width=1.5,
    ).move_to(_pt(0.0, 1.80))   # centre at y = (0.70+2.90)/2 = 1.80

    screen = Rectangle(
        width=2.16, height=1.96,
        color=SCREEN_OFF, fill_color=SCREEN_OFF, fill_opacity=1.0,
        stroke_width=0,
    ).move_to(_pt(0.0, 1.80))

    stand = Rectangle(
        width=0.24, height=0.40,
        color=MONITOR_BEZEL, fill_color=MONITOR_BEZEL, fill_opacity=1.0,
        stroke_width=1.0,
    ).move_to(_pt(0.0, 0.50))   # centre at y = (0.70+0.30)/2 = 0.50

    base = Rectangle(
        width=0.70, height=0.10,
        color=MONITOR_BEZEL, fill_color=MONITOR_BEZEL, fill_opacity=1.0,
        stroke_width=1.0,
    ).move_to(_pt(0.0, 0.33))

    return VGroup(bezel, screen, stand, base)


def _build_keyboard() -> VGroup:
    """Return keyboard as a flat rectangle with subtle key rows."""
    body = Rectangle(
        width=1.50, height=0.20,
        color=KB_COLOR, fill_color=KB_COLOR, fill_opacity=1.0,
        stroke_width=1.5,
    ).move_to(_pt(0.0, 0.44))   # centre at y = (0.34+0.54)/2 = 0.44

    # Three thin lines to suggest key rows
    rows = VGroup()
    for dy in [-0.05, 0.00, 0.05]:
        rows.add(
            Line(_pt(-0.65, 0.44 + dy), _pt(0.65, 0.44 + dy),
                 color=GRAY, stroke_width=0.5)
        )
    return VGroup(body, rows)


def _build_chair() -> VGroup:
    """Return chair assembly: seat + back + four legs."""
    # Seat — slight trapezoid
    seat = Polygon(
        _pt(-0.60, -1.10),  # back-left
        _pt( 0.60, -1.10),  # back-right
        _pt( 0.70, -1.30),  # front-right
        _pt(-0.70, -1.30),  # front-left
        color=CHAIR_SEAT, fill_color=CHAIR_SEAT, fill_opacity=1.0,
        stroke_width=1.5,
    )

    # Chair back (vertical slab rising from back of seat)
    back = Rectangle(
        width=1.10, height=1.25,
        color=CHAIR_SEAT, fill_color=CHAIR_SEAT, fill_opacity=0.85,
        stroke_color=CHAIR_FRAME, stroke_width=1.5,
    ).move_to(_pt(0.0, -0.475))  # centre at y = (-1.10 + 0.15)/2

    # Front legs
    fl_leg = Line(_pt(-0.65, -1.30), _pt(-0.60, -3.30),
                  color=CHAIR_FRAME, stroke_width=2.5)
    fr_leg = Line(_pt( 0.65, -1.30), _pt( 0.60, -3.30),
                  color=CHAIR_FRAME, stroke_width=2.5)
    # Back legs (slightly inset, shorter visible length)
    bl_leg = Line(_pt(-0.52, -1.10), _pt(-0.55, -3.10),
                  color=CHAIR_FRAME, stroke_width=2.0)
    br_leg = Line(_pt( 0.52, -1.10), _pt( 0.55, -3.10),
                  color=CHAIR_FRAME, stroke_width=2.0)

    return VGroup(bl_leg, br_leg, fl_leg, fr_leg, back, seat)


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

class ComputerDesk(Scene):
    """Static pseudo-3D computer desk viewed from a few feet away."""

    def construct(self) -> None:
        self.camera.background_color = "#1a1a1a"

        # --- build elements ---
        floor = Line(_pt(-7.0, -3.50), _pt(7.0, -3.50),
                     color=FLOOR_COLOR, stroke_width=1.5)

        desk    = _build_desk()
        monitor = _build_monitor()
        keyboard = _build_keyboard()
        chair   = _build_chair()

        # Screen is monitor[1] — we'll animate the colour separately
        screen_rect = monitor[1]

        # --- phase 0.0–0.5 s : desk + floor ---
        self.play(FadeIn(floor), FadeIn(desk), run_time=0.5)

        # --- phase 0.5–0.9 s : monitor ---
        self.play(FadeIn(monitor), run_time=0.4)

        # --- phase 0.9–1.2 s : keyboard ---
        self.play(FadeIn(keyboard), run_time=0.3)

        # --- phase 1.2–1.8 s : chair ---
        self.play(FadeIn(chair), run_time=0.6)

        # --- phase 1.8–2.4 s : screen flickers on ---
        self.play(
            screen_rect.animate.set_fill(SCREEN_ON, opacity=1.0),
            run_time=0.6,
        )

        # --- phase 2.4–3.0 s : gentle pulse dim ---
        self.play(
            screen_rect.animate.set_fill(SCREEN_ON, opacity=0.65),
            run_time=0.6,
            rate_func=there_and_back,
        )

        # --- phase 3.0–4.0 s : hold ---
        self.wait(1.0)
