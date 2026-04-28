from manim import *
from Scenes.wall_clock_scene import WallClockScene, WallClockSceneHD


class WallClockSceneHD(WallClockSceneHD):
    """Default rendering configuration for wall clock animation."""
    pass


class MovingCameraTemplate(MovingCameraScene):
    def construct(self):
        text = Text("Hello World").set_color(BLUE)
        self.add(text)
        self.camera.frame.save_state()
        self.play(self.camera.frame.animate.set(width=text.width * 1.2))
        self.wait(0.3)
        self.play(Restore(self.camera.frame))
