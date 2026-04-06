namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>The Manim Python base class from which a scene class inherits.</summary>
  public enum ManimSceneBaseClassEnum
  {
    /// <summary>Standard 2D scene.</summary>
    Scene,
    /// <summary>Three-dimensional scene with camera rotation support.</summary>
    ThreeDScene,
    /// <summary>Scene with a camera that can pan and zoom.</summary>
    MovingCameraScene,
    /// <summary>Scene that supports a magnified inset view.</summary>
    ZoomedScene,
  }
}
