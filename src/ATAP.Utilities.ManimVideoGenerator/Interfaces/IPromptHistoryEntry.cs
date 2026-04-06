using System;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// A single entry in the prompt/response history captured during the
  /// AI pipeline run that produced a scene.
  /// </summary>
  public interface IPromptHistoryEntry
  {
    /// <summary>The role of the actor that produced this entry (e.g. "User", agent name).</summary>
    string Role { get; }

    /// <summary>The text content of the prompt or response.</summary>
    string Content { get; }

    /// <summary>UTC timestamp when this entry was recorded.</summary>
    DateTime At { get; }
  }
}
