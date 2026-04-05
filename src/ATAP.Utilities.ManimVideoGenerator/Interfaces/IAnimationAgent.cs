using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Represents a single AI agent in the two-stage text-to-Manim pipeline.
  /// </summary>
  public interface IAnimationAgent
  {
    /// <summary>Gets the role this agent plays in the pipeline.</summary>
    AgentRoleEnum Role { get; }

    /// <summary>
    /// Executes the agent against the supplied context and returns a result.
    /// </summary>
    Task<IAgentResult> ExecuteAsync(IAgentContext context, CancellationToken cancellationToken = default);
  }
}
