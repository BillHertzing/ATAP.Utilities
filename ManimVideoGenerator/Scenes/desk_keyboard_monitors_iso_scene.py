"""DeskKeyboardMonitors_ISO_Projection Scene
============================================
Same physical setup as DeskKeyboardMonitors but viewed from
the front-right at a slight elevation — an oblique/cabinet projection.

World coordinate axes
---------------------
  wx : left → right           range ≈ −5.0 … +5.0
  wd : back(0) → front(+)     depth range  0.0 … 2.5
  wz : floor(0) → up           range ≈  0.0 … +3.5
       desk surface = wz 0, floor = wz -2.5

Projection  (view from front-right, slight elevation)
------------------------------------------------------
  sx = wx * Kx  + wd * Kd_x
  sy = wz * Kz  + wd * Kd_y

  Kx   =  0.65   (world x → screen x)
  Kd_x = +0.44   (depth pushes screen-right — right-side viewpoint)
  Kz   =  1.00   (world z → screen y)
  Kd_y =  0.28   (depth pushes screen-up — elevation illusion)

Viewport: x in [-7.1, 7.1], y in [-4.0, 4.0]
"""

from manim import *
import numpy as np

# ── Style ──────────────────────────────────────────────────────────────────
INK        = "#1C1C1C"
LITE       = "#6A6A6A"
BG         = WHITE
SW         = 2.0
SW_D       = 1.2
FILL_FACE  = 0.06   # faint fill for faces
FILL_SCRN  = 0.03   # even fainter for screen insets

# ── Projection ─────────────────────────────────────────────────────────────
Kx, Kd_x, Kz, Kd_y = 0.65, +0.44, 1.00, 0.28

# Real-world dimensions mapped into scene units.
# Desk width (1854 mm) is mapped to world width 10.0 units.
MM_TO_U = 10.0 / 1854.0

DESK_W_MM = 1854.0
DESK_OPEN_MM = 1130.0
RISER_W_MM = 1016.0

CENTER_MON_W_MM = 726.0     # PG320 landscape width
# Use a visual target aspect for this sketch: H:W = 3:4
CENTER_MON_H_MM = CENTER_MON_W_MM * (3.0 / 4.0)

ASUS_W_MM = 540.02          # ASUS VS238 landscape width
ASUS_H_MM = 398.78          # ASUS VS238 landscape height

MON_GAP_MM = 25.0           # Gap between center monitor and each flanking monitor


def p(wx: float, wd: float, wz: float) -> np.ndarray:
    """Project world (wx, wd, wz) → Manim 2-D screen vector."""
    return np.array([wx * Kx + wd * Kd_x,
                     wz * Kz + wd * Kd_y,
                     0.0])


# ── Geometry helpers ───────────────────────────────────────────────────────

def face(pts, sw=SW, fill_op=FILL_FACE, fill_color=None):
    """Polygon from list of projected 3-vectors."""
    fc = fill_color if fill_color is not None else INK
    return Polygon(*pts,
                   color=INK,
                   fill_color=fc,
                   fill_opacity=fill_op,
                   stroke_width=sw)


def edge(a, b, sw=SW_D, color=LITE):
    return Line(a, b, color=color, stroke_width=sw)


# ── Desk ───────────────────────────────────────────────────────────────────

def _desk() -> VGroup:
    X0, X1  = -5.0,  5.0   # desk left / right
    D0, D1  =  0.0,  2.5   # desk front / back depth
    Z_SURF  =  0.0         # desk surface
    Z_FLOOR = -2.5         # floor level

    # ── Side faces drawn FIRST so the opaque frnt/top cover their back edges ──

    # Left side face
    lside = face([p(X0, D0, Z_FLOOR), p(X0, D1, Z_FLOOR),
                  p(X0, D1, Z_SURF),  p(X0, D0, Z_SURF)])

    # Right side face (Lines needed — right annotation)
    rside = face([p(X1, D0, Z_FLOOR), p(X1, D1, Z_FLOOR),
                  p(X1, D1, Z_SURF),  p(X1, D0, Z_SURF)])

    # ── Pedestal bounds ──
    opening_w = DESK_OPEN_MM * MM_TO_U
    half_open = opening_w / 2.0
    LX0, LX1 = X0, -half_open
    RX0, RX1 = half_open, X1

    # Inner pedestal depth faces — before frnt so their back edges are occluded
    rpl  = face([p(RX0, D0, Z_FLOOR), p(RX0, D1, Z_FLOOR),
                 p(RX0, D1, Z_SURF),  p(RX0, D0, Z_SURF)], sw=SW)

    # ── Opaque white top surface — covers side-face overlaps, occluded by monitors later ──
    top = face([p(X0, D1, Z_SURF), p(X1, D1, Z_SURF),
                p(X1, D0, Z_SURF), p(X0, D0, Z_SURF)],
               fill_op=0.92, fill_color=WHITE)

    # ── Opaque white front face — hides back edges of side faces (Line should be hidden) ──
    frnt = face([p(X0, D0, Z_FLOOR), p(X1, D0, Z_FLOOR),
                 p(X1, D0, Z_SURF),  p(X0, D0, Z_SURF)],
                fill_op=0.92, fill_color=WHITE)

    # Pedestal top faces — on top of desk top surface
    lpt  = face([p(LX0, D1, Z_SURF),  p(LX1, D1, Z_SURF),
                 p(LX1, D0, Z_SURF),  p(LX0, D0, Z_SURF)], sw=SW_D,
                fill_op=0.92, fill_color=WHITE)
    rpt  = face([p(RX0, D1, Z_SURF),  p(RX1, D1, Z_SURF),
                 p(RX1, D0, Z_SURF),  p(RX0, D0, Z_SURF)], sw=SW_D,
                fill_op=0.92, fill_color=WHITE)

    # Pedestal front faces — on top of frnt
    lpf  = face([p(LX0, D0, Z_FLOOR), p(LX1, D0, Z_FLOOR),
                 p(LX1, D0, Z_SURF),  p(LX0, D0, Z_SURF)], sw=SW_D,
                fill_op=1.0, fill_color=WHITE)
    rpf  = face([p(RX0, D0, Z_FLOOR), p(RX1, D0, Z_FLOOR),
                 p(RX1, D0, Z_SURF),  p(RX0, D0, Z_SURF)], sw=SW_D,
                fill_op=1.0, fill_color=WHITE)

    lp_ds = VGroup(*[edge(p(LX0, D0, z), p(LX1, D0, z)) for z in [-0.83, -1.65]])
    rp_ds = VGroup(*[edge(p(RX0, D0, z), p(RX1, D0, z)) for z in [-0.83, -1.65]])

    # Inner pedestal vertical edge lines
    ped_l = edge(p(LX1, D0, Z_SURF), p(LX1, D0, Z_FLOOR), color=INK, sw=SW)
    ped_r = edge(p(RX0, D0, Z_SURF), p(RX0, D0, Z_FLOOR), color=INK, sw=SW)

    # Desk back-bottom edge across the center panel (visible floor of the desk cavity)
    back_bot = edge(p(LX1, D1, Z_FLOOR), p(RX0, D1, Z_FLOOR), color=INK, sw=SW_D)
    # Left pedestal inner face: floor line running from front to back (viewer's left pedestal)
    lped_inner_fl = edge(p(LX1, D0, Z_FLOOR), p(LX1, D1, Z_FLOOR), color=INK, sw=SW_D)
    # Left pedestal inner face: vertical back edge
    lped_back_vert = edge(p(LX1, D1, Z_SURF), p(LX1, D1, Z_FLOOR), color=INK, sw=SW_D)

    # Floor line — trimmed to exact desk width (erase overhang)
    fl = edge(p(X0, D0, Z_FLOOR), p(X1, D0, Z_FLOOR), color=INK, sw=SW)

    # Order: side faces first → opaque top/frnt cover their back edges → details on top
    return VGroup(lside, rside, rpl,
                  top, frnt, lpt, rpt,
                  lpf, rpf, lp_ds, rp_ds,
                  ped_l, ped_r,
                  back_bot, lped_inner_fl, lped_back_vert,
                  fl)


# ── Riser (VARIDESK) ────────────────────────────────────────────────────────

def _riser() -> VGroup:
    riser_w = RISER_W_MM * MM_TO_U
    BX0, BX1 = -riser_w / 2.0, riser_w / 2.0
    BD0, BD1 =  0.4,  2.2
    BZ0, BZ1 =  0.0,  0.38

    bt = face([p(BX0, BD1, BZ1), p(BX1, BD1, BZ1),
               p(BX1, BD0, BZ1), p(BX0, BD0, BZ1)],
              fill_op=1.0, fill_color=WHITE)
    bf = face([p(BX0, BD0, BZ0), p(BX1, BD0, BZ0),
               p(BX1, BD0, BZ1), p(BX0, BD0, BZ1)],
              fill_op=1.0, fill_color=WHITE)
    # RIGHT side face visible from right-side viewpoint (was incorrectly left side)
    br = face([p(BX1, BD0, BZ0), p(BX1, BD1, BZ0),
               p(BX1, BD1, BZ1), p(BX1, BD0, BZ1)],
              fill_op=0.92, fill_color=WHITE)

    # Raised shelf in center (keyboard sits here)
    # SD1 clipped to 1.4 so shelf does not extend behind monitor face at depth 1.5
    SX0, SX1 = -1.4,  1.4
    SD0, SD1 =  0.4,  1.4
    SZ0, SZ1 = BZ1, BZ1 + 0.30

    st = face([p(SX0, SD1, SZ1), p(SX1, SD1, SZ1),
               p(SX1, SD0, SZ1), p(SX0, SD0, SZ1)],
              fill_op=0.92, fill_color=WHITE)
    sf = face([p(SX0, SD0, SZ0), p(SX1, SD0, SZ0),
               p(SX1, SD0, SZ1), p(SX0, SD0, SZ1)],
              fill_op=0.92, fill_color=WHITE)
    # Right side face of shelf (visible from right-side viewpoint)
    sr = face([p(SX1, SD0, SZ0), p(SX1, SD1, SZ0),
               p(SX1, SD1, SZ1), p(SX1, SD0, SZ1)],
              fill_op=0.92, fill_color=WHITE)

    return VGroup(bt, bf, br, st, sf, sr)


# ── Keyboards ──────────────────────────────────────────────────────────────

def _keyboards() -> VGroup:
    # Lower pull-out tray (wd < 0 = in front of desk front edge)
    LKX0, LKX1 = -2.7,  2.7
    LKD0, LKD1 = -0.7,  1.0
    LKZ = -0.30

    lk_top  = face([p(LKX0, LKD1, LKZ), p(LKX1, LKD1, LKZ),
                    p(LKX1, LKD0, LKZ), p(LKX0, LKD0, LKZ)],
                   sw=SW_D, fill_op=1.0, fill_color=WHITE)
    lk_frnt = face([p(LKX0, LKD0, LKZ - 0.06), p(LKX1, LKD0, LKZ - 0.06),
                    p(LKX1, LKD0, LKZ),          p(LKX0, LKD0, LKZ)],
                   sw=SW_D, fill_op=1.0, fill_color=WHITE)

    return VGroup(lk_top, lk_frnt)


# ── Monitors ───────────────────────────────────────────────────────────────

def _monitors() -> VGroup:
    # Compensate x-dimension for oblique projection compression (Kx < 1)
    # so monitors render with their intended landscape visual proportions.
    width_comp = 1.0 / Kx

    c_w = CENTER_MON_W_MM * MM_TO_U * width_comp
    c_h = CENTER_MON_H_MM * MM_TO_U
    a_w = ASUS_W_MM * MM_TO_U * width_comp
    a_h = ASUS_H_MM * MM_TO_U
    gap = MON_GAP_MM * MM_TO_U * width_comp

    c_half_w = c_w / 2.0
    a_half_w = a_w / 2.0

    # ── Centre-lower (large, on riser base) ──
    CLX0, CLX1 = -c_half_w, c_half_w
    # Center this monitor on the second riser depth range (SD0..SD1 = 0.4..1.4)
    CLD        =  0.90
    CLZ0, CLZ1 =  0.38, 0.38 + c_h
    center_zc = (CLZ0 + CLZ1) / 2.0

    cl_f  = face([p(CLX0, CLD, CLZ0), p(CLX1, CLD, CLZ0),
                  p(CLX1, CLD, CLZ1), p(CLX0, CLD, CLZ1)],
                 fill_op=1.0, fill_color=WHITE)
    # Visible left-side edge thickness
    cl_s  = face([p(CLX0, CLD,       CLZ0), p(CLX0, CLD + 0.08, CLZ0),
                  p(CLX0, CLD + 0.08, CLZ1), p(CLX0, CLD,       CLZ1)],
                 sw=SW_D, fill_op=1.0, fill_color=WHITE)
    # Screen inset — 100% opaque white
    cl_in = face([p(CLX0 * 0.88, CLD, CLZ0 + 0.14),
                  p(CLX1 * 0.88, CLD, CLZ0 + 0.14),
                  p(CLX1 * 0.88, CLD, CLZ1 - 0.10),
                  p(CLX0 * 0.88, CLD, CLZ1 - 0.10)],
                 sw=SW_D, fill_op=1.0, fill_color=WHITE)

    # ── Centre-upper (stacked above on monitor arm) ──
    CUX0, CUX1 = -a_half_w, a_half_w
    CUD        =  CLD
    # Bottom edge is 25mm above center monitor top edge.
    CUZ0, CUZ1 =  CLZ1 + gap, CLZ1 + gap + a_h

    cu_f  = face([p(CUX0, CUD, CUZ0), p(CUX1, CUD, CUZ0),
                  p(CUX1, CUD, CUZ1), p(CUX0, CUD, CUZ1)],
                 fill_op=1.0, fill_color=WHITE)
    cu_in = face([p(CUX0 * 0.86, CUD, CUZ0 + 0.10),
                  p(CUX1 * 0.86, CUD, CUZ0 + 0.10),
                  p(CUX1 * 0.86, CUD, CUZ1 - 0.08),
                  p(CUX0 * 0.86, CUD, CUZ1 - 0.08)],
                 sw=SW_D, fill_op=1.0, fill_color=WHITE)
    cu_arm = edge(p(0, CUD, CUZ0), p(0, CUD, CUZ0 + 0.25))

    # ── Left monitor (on desk surface, slightly angled — barely visible) ──
    # Inside edges align with center monitor edges + 25 mm gap.
    left_inner = CLX0 - gap
    left_outer = left_inner - a_w
    LMX0, LMX1 = left_outer, left_inner
    LMD        =  1.0
    # Align flanking monitor horizontal centerline with center monitor centerline.
    LMZ0, LMZ1 = center_zc - a_h / 2.0, center_zc + a_h / 2.0

    lm_f  = face([p(LMX0, LMD, LMZ0), p(LMX1, LMD, LMZ0),
                  p(LMX1, LMD, LMZ1), p(LMX0, LMD, LMZ1)],
                 fill_op=1.0, fill_color=WHITE)
    lm_in = face([p(LMX0 + 0.14, LMD, LMZ0 + 0.14),
                  p(LMX1 - 0.14, LMD, LMZ0 + 0.14),
                  p(LMX1 - 0.14, LMD, LMZ1 - 0.12),
                  p(LMX0 + 0.14, LMD, LMZ1 - 0.12)],
                 sw=SW_D, fill_op=1.0, fill_color=WHITE)

    # ── Right monitor (on desk surface, most visible in this view) ──
    right_inner = CLX1 + gap
    right_outer = right_inner + a_w
    RMX0, RMX1 = right_inner, right_outer
    RMD        = 1.0
    RMZ0, RMZ1 = center_zc - a_h / 2.0, center_zc + a_h / 2.0

    rm_f  = face([p(RMX0, RMD, RMZ0), p(RMX1, RMD, RMZ0),
                  p(RMX1, RMD, RMZ1), p(RMX0, RMD, RMZ1)],
                 fill_op=1.0, fill_color=WHITE)
    # Visible left-side edge
    rm_s  = face([p(RMX0, RMD,       RMZ0), p(RMX0, RMD + 0.08, RMZ0),
                  p(RMX0, RMD + 0.08, RMZ1), p(RMX0, RMD,       RMZ1)],
                 sw=SW_D)
    rm_in = face([p(RMX0 + 0.14, RMD, RMZ0 + 0.14),
                  p(RMX1 - 0.14, RMD, RMZ0 + 0.14),
                  p(RMX1 - 0.14, RMD, RMZ1 - 0.12),
                  p(RMX0 + 0.14, RMD, RMZ1 - 0.12)],
                 sw=SW_D, fill_op=1.0, fill_color=WHITE)

    return VGroup(cl_f, cl_s, cl_in,
                  cu_f, cu_in, cu_arm,
                  lm_f, lm_in,
                  rm_f, rm_s, rm_in)


# ── Scene ──────────────────────────────────────────────────────────────────

class DeskKeyboardMonitors_ISO_Projection(Scene):
    """Oblique/ISO outline sketch of the desk setup viewed from front-right."""

    def construct(self):
        self.camera.background_color = BG

        desk      = _desk()
        riser     = _riser()
        keyboards = _keyboards()
        monitors  = _monitors()

        # Reduce entire scene by 25%.
        VGroup(desk, riser, keyboards, monitors).scale(0.75)

        # Reveal back-to-front: desk structure first, then equipment
        self.play(FadeIn(desk),      run_time=0.6)
        self.play(FadeIn(riser),     run_time=0.4)
        self.play(FadeIn(monitors),  run_time=0.6)
        self.play(FadeIn(keyboards), run_time=0.4)
        self.wait(2.0)
