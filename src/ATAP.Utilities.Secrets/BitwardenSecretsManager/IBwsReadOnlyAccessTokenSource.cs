namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public interface IBwsReadOnlyAccessTokenSource
{
  ValueTask<IBwsAccessTokenLease> AcquireAsync(CancellationToken cancellationToken = default);
}
