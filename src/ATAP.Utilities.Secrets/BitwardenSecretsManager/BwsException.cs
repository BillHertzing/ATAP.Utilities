namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed class BwsException : Exception
{
  public BwsException(BwsFailureKind kind, string message) : base(message) { Kind = kind; }
  public BwsException(BwsFailureKind kind, string message, Exception innerException) : base(message, innerException) { Kind = kind; }
  public BwsFailureKind Kind { get; }
}