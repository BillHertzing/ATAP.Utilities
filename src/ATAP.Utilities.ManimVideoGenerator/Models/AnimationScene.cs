using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Core aggregate representing an AI-generated Manim animation scene and its
  /// associated render artefacts.
  /// </summary>
  public record AnimationScene : IAnimationScene
  {
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string ManimCode { get; set; } = string.Empty;
    public string? VideoPath { get; set; }
    public RenderStatusEnum Status { get; set; } = RenderStatusEnum.Draft;
    public IList<IPromptHistoryEntry> PromptHistory { get; init; } = new List<IPromptHistoryEntry>();
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
  }
}
