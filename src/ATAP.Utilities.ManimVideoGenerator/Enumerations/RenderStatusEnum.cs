namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>Lifecycle status of a rendered animation scene.</summary>
  public enum RenderStatusEnum
  {
    /// <summary>Scene created; Manim code not yet submitted for rendering.</summary>
    Draft,
    /// <summary>Background render job is actively running.</summary>
    Rendering,
    /// <summary>Rendering completed successfully; the MP4 file is available.</summary>
    Ready,
    /// <summary>Rendering failed; see the associated error message for details.</summary>
    Failed,
  }
}
