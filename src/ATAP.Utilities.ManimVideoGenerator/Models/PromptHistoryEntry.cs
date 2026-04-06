using System;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Immutable record of a single prompt or response captured during the
  /// AI pipeline run that produced an <see cref="AnimationScene"/>.
  /// </summary>
  public record PromptHistoryEntry(string Role, string Content, DateTime At) : IPromptHistoryEntry;
}
