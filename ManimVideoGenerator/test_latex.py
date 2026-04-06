# test_latex.py — §10.7 LaTeX verification scene
from manim import *


class LatexTest(Scene):
    def construct(self):
        eq = MathTex(r"e^{i\pi} + 1 = 0")
        self.play(Write(eq))
        self.wait(1)
