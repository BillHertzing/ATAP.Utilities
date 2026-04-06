namespace ATAP.Utilities.ManimVideoGenerator {
  /// <summary>Render quality levels corresponding to the Manim CLI quality flags.</summary>
  public enum ManimQualityEnum {
    /// <summary>480p at 15 fps (-ql)</summary>
    Low480p15,
    /// <summary>720p at 30 fps (-qm)</summary>
    Medium720p30,
    /// <summary>1080p at 60 fps (-qh)</summary>
    High1080p60,
    /// <summary>2160p (4K) at 60 fps (-qk)</summary>
    Ultra2160p60,
  }
}
