namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Immutable result returned by an <see cref="IAnimationAgent"/> after a single execution.
  /// </summary>
  public record AgentResult : IAgentResult
  {
    public ValidationStatusEnum Status { get; init; }
    public string Output { get; init; } = string.Empty;
    public string? RejectionReason { get; init; }

    public static AgentResult Approved(string output) =>
      new() { Status = ValidationStatusEnum.Approved, Output = output };

    public static AgentResult Rejected(string output, string reason) =>
      new() { Status = ValidationStatusEnum.Rejected, Output = output, RejectionReason = reason };
  }
}
