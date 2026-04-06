# test_manim.py — §10.6 verification scene
from manim import *


class HelloManim(Scene):
    def construct(self):
        text = Text("Hello, Manim!")
        self.play(Write(text))
        self.wait(1)
