using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Orchestrates the full two-stage pipeline: description expansion → code generation.
  /// Implemented by AnimationOrchestrator using Microsoft.SemanticKernel agents.
  /// </summary>
  public interface IAnimationOrchestrator
  {
    /// <summary>
    /// Runs the full pipeline for the given user prompt and returns a populated
    /// <see cref="IAnimationScene"/> whose ManimCode is ready for rendering.
    /// </summary>
    Task<IAnimationScene> GenerateAsync(string userPrompt, CancellationToken cancellationToken = default);
  }
}
