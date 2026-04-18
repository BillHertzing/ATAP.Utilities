"""ManimVideoGenerator Scenes library."""
from .wall_clock_scene import WallClockScene, WallClockSceneHD
from .stick_figure_base_scene import StickFigureBase
from .stick_figure_pirouette_scene import StickFigurePirouette
from .stick_figure_walking_scene import StickFigureWalking
from .computer_desk_scene import ComputerDesk

__all__ = [
    'WallClockScene', 'WallClockSceneHD',
    'StickFigureBase',
    'StickFigurePirouette',
    'StickFigureWalking',
    'ComputerDesk',
]
