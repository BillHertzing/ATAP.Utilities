using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Core aggregate representing a single AI-generated animation scene and its
  /// associated render artefacts.
  /// </summary>
  public interface IAnimationScene
  {
    /// <summary>Unique identifier for this scene.</summary>
    Guid Id { get; }

    /// <summary>Human-readable name for the scene.</summary>
    string Name { get; set; }

    /// <summary>The generated Manim Python script text.</summary>
    string ManimCode { get; set; }

    /// <summary>Absolute local path to the rendered MP4 file; null until rendering completes.</summary>
    string? VideoPath { get; set; }

    /// <summary>Current lifecycle status of the scene.</summary>
    RenderStatusEnum Status { get; set; }

    /// <summary>Ordered history of prompts and agent responses during generation.</summary>
    IList<IPromptHistoryEntry> PromptHistory { get; }

    /// <summary>UTC timestamp when this scene record was created.</summary>
    DateTime CreatedAt { get; }

    /// <summary>UTC timestamp of the most recent modification.</summary>
    DateTime UpdatedAt { get; set; }
  }
}
