using System;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Mutable state bag passed between each agent in a single pipeline run.
  /// </summary>
  public class AgentContext : IAgentContext
  {
    public Guid RunId { get; init; } = Guid.NewGuid();
    public string OriginalPrompt { get; init; } = string.Empty;
    public string CurrentText { get; set; } = string.Empty;
    public int IterationCount { get; set; } = 0;

    public AgentContext(string originalPrompt)
    {
      OriginalPrompt = originalPrompt;
      CurrentText = originalPrompt;
    }
  }
}
