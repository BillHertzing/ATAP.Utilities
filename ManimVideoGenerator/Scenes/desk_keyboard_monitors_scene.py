"""DeskKeyboardMonitors Scene
==============================
Simplified outline sketch of the actual desk setup (April 2026).

Real setup (from photos):
  - Wide white desk with drawer pedestals on each side
  - VARIDESK-style riser on desk surface (raises center monitors + upper keyboard)
  - Upper keyboard tray on riser, with mouse
  - Lower pull-out keyboard tray under desk (full-size mechanical KB)
  - 4 monitors:
      left  — ASUS landscape, on desk surface, angled inward
      center-lower — large curved, on riser
      center-upper — standard, stacked above center-lower on riser arm
      right  — ASUS landscape, on desk surface, angled inward

Style: outline sketch — no fills, white background, dark strokes.

Viewport: x in [-7.1, 7.1], y in [-4.0, 4.0]
"""

from manim import *


# ---------------------------------------------------------------------------
# Style constants
# ---------------------------------------------------------------------------
INK       = "#1C1C1C"   # main outline colour
LITE      = "#6A6A6A"   # secondary / detail lines
BG        = WHITE
SW        = 2.0         # default stroke width
SW_DETAIL = 1.2         # thinner detail lines
FILL_OP   = 0.06        # very faint fill for depth


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _rect(x0: float, y0: float, x1: float, y1: float,
          color: str = INK, fill_op: float = FILL_OP,
          sw: float = SW) -> Rectangle:
    """Rectangle from two corner coordinates."""
    return Rectangle(
        width=abs(x1 - x0),
        height=abs(y1 - y0),
        color=color,
        fill_color=INK,
        fill_opacity=fill_op,
        stroke_width=sw,
    ).move_to([(x0 + x1) / 2, (y0 + y1) / 2, 0])


def _hline(x0: float, x1: float, y: float, sw: float = SW_DETAIL) -> Line:
    return Line([x0, y, 0], [x1, y, 0], color=LITE, stroke_width=sw)


# ---------------------------------------------------------------------------
# Builder functions
# ---------------------------------------------------------------------------

def _build_desk() -> VGroup:
    """Desk surface + two drawer pedestals."""
    # Main desk surface — very wide, shallow
    surface = _rect(-6.5, -1.10, 6.5, -0.85)

    # Left drawer pedestal (3 drawers)
    left = _rect(-6.10, -3.60, -4.30, -1.10)
    left_dividers = VGroup(
        _hline(-6.10, -4.30, -1.87),
        _hline(-6.10, -4.30, -2.65),
    )

    # Right drawer pedestal (3 drawers)
    right = _rect(4.30, -3.60, 6.10, -1.10)
    right_dividers = VGroup(
        _hline(4.30, 6.10, -1.87),
        _hline(4.30, 6.10, -2.65),
    )

    # Floor line
    floor = Line([-7.0, -3.75, 0], [7.0, -3.75, 0], color=INK, stroke_width=SW_DETAIL)

    return VGroup(surface, left, left_dividers, right, right_dividers, floor)


def _build_riser() -> VGroup:
    """VARIDESK-style desk riser sitting on the desk surface."""
    # Riser base platform (wide, sits on desk top)
    base = _rect(-3.60, -0.85, 3.60, -0.40)
    # Riser shelf / raised keyboard surface
    shelf = _rect(-1.80, -0.40, 1.80, -0.10)
    return VGroup(base, shelf)


def _build_keyboards() -> VGroup:
    """Upper keyboard on riser shelf + lower pull-out tray keyboard."""
    # Keyboard sitting on riser shelf
    kb_upper = _rect(-1.50, -0.35, 1.50, -0.17, sw=SW_DETAIL)

    # Pull-out tray under desk (extends below desk surface level)
    tray = _rect(-3.00, -1.65, 3.00, -1.38)
    # Full-size keyboard on tray
    kb_lower = _rect(-2.60, -1.62, 2.60, -1.45, sw=SW_DETAIL)

    return VGroup(kb_upper, tray, kb_lower)


def _build_monitors() -> VGroup:
    """4-monitor arrangement as simple outline rectangles."""

    # --- Center lower (large, on riser) ---
    ctr_lo_bezel  = _rect(-2.10, -0.10, 2.10, 2.15)
    ctr_lo_screen = _rect(-1.92,  0.06, 1.92, 1.98,
                          fill_op=0.04, sw=SW_DETAIL)

    # --- Center upper (stacked above, on monitor arm) ---
    ctr_hi_bezel  = _rect(-1.55, 2.15, 1.55, 3.35)
    ctr_hi_screen = _rect(-1.38, 2.28, 1.38, 3.22,
                          fill_op=0.04, sw=SW_DETAIL)
    # Simple arm line connecting two center monitors
    arm = Line([0, 2.15, 0], [0, 2.50, 0], color=LITE, stroke_width=SW_DETAIL)

    # --- Left monitor (on desk surface, angled inward — approx as skewed rect) ---
    # Approximate the angle with a simple parallelogram-like polygon
    left_mon = Polygon(
        [-6.40, -1.00, 0],   # bottom-left corner (on desk)
        [-3.40, -1.00, 0],   # bottom-right corner
        [-3.20,  1.55, 0],   # top-right
        [-6.20,  1.55, 0],   # top-left
        color=INK, fill_color=INK, fill_opacity=FILL_OP, stroke_width=SW,
    )
    left_screen = Polygon(
        [-6.22, -0.84, 0],
        [-3.53, -0.84, 0],
        [-3.35,  1.38, 0],
        [-6.05,  1.38, 0],
        color=LITE, fill_color=INK, fill_opacity=0.04, stroke_width=SW_DETAIL,
    )

    # --- Right monitor (mirror of left) ---
    right_mon = Polygon(
        [ 3.40, -1.00, 0],
        [ 6.40, -1.00, 0],
        [ 6.20,  1.55, 0],
        [ 3.20,  1.55, 0],
        color=INK, fill_color=INK, fill_opacity=FILL_OP, stroke_width=SW,
    )
    right_screen = Polygon(
        [ 3.53, -0.84, 0],
        [ 6.22, -0.84, 0],
        [ 6.05,  1.38, 0],
        [ 3.35,  1.38, 0],
        color=LITE, fill_color=INK, fill_opacity=0.04, stroke_width=SW_DETAIL,
    )

    return VGroup(
        ctr_lo_bezel, ctr_lo_screen,
        ctr_hi_bezel, ctr_hi_screen, arm,
        left_mon, left_screen,
        right_mon, right_screen,
    )


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

class DeskKeyboardMonitors(Scene):
    """Outline sketch of the desk-keyboard-monitors setup."""

    def construct(self):
        self.camera.background_color = BG

        desk      = _build_desk()
        riser     = _build_riser()
        keyboards = _build_keyboards()
        monitors  = _build_monitors()

        # Fade in from back to front, desk → riser → monitors → keyboards
        self.play(FadeIn(desk),      run_time=0.6)
        self.play(FadeIn(riser),     run_time=0.4)
        self.play(FadeIn(monitors),  run_time=0.6)
        self.play(FadeIn(keyboards), run_time=0.4)
        self.wait(2.0)
