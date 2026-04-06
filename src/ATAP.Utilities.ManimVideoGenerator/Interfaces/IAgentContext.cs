using System;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Carries state between agent invocations within a single pipeline run.
  /// </summary>
  public interface IAgentContext
  {
    /// <summary>Unique identifier for this pipeline run.</summary>
    Guid RunId { get; }

    /// <summary>The original user-supplied prompt.</summary>
    string OriginalPrompt { get; }

    /// <summary>The accumulated conversation / working text that agents read and write.</summary>
    string CurrentText { get; set; }

    /// <summary>Number of refinement iterations completed so far.</summary>
    int IterationCount { get; set; }
  }
}
