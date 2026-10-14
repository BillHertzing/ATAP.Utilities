namespace ATAP.Utilities.Secrets;

internal static class BitwardenPasswordManagerCompatibility
{
  public const string Message = "Password Manager CLI compatibility is obsolete. Use ATAP.Utilities.Secrets.BitwardenSecretsManager and its explicit bws/Project API. Removal target: 1.0.0.";
  public const string DiagnosticId = "ATAPSECRETS001";
  public const string UrlFormat = "https://github.com/ATAPUtilities/ATAP.Utilities/blob/main/src/ATAP.Utilities.Secrets/BitwardenSecretsManager/ReadMe.md";
  public const string SessionEnvironmentVariable = "BW_SESSION";
  public const string CliPath = "bw";
  public const string Timeout = "00:00:30";
  public const string SessionMissing = "BW_SESSION is not set; this obsolete Password Manager compatibility provider is unavailable.";
}