namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public interface IBwsProcessRunner
{
  Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default);
}
