namespace ATAP.Utilities.Secrets;

using System;

[System.Obsolete(BitwardenPasswordManagerCompatibility.Message, DiagnosticId = BitwardenPasswordManagerCompatibility.DiagnosticId, UrlFormat = BitwardenPasswordManagerCompatibility.UrlFormat)]
public class BitwardenSecretsOptions
{
  public string SessionEnvVarName { get; set; } = BitwardenPasswordManagerCompatibility.SessionEnvironmentVariable;
  public string BwCliPath { get; set; } = BitwardenPasswordManagerCompatibility.CliPath;
  public TimeSpan Timeout { get; set; } = TimeSpan.Parse(BitwardenPasswordManagerCompatibility.Timeout);
  public string DefaultFieldName { get; set; } = "password";
}
