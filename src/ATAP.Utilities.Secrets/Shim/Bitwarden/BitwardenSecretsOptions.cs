namespace ATAP.Utilities.Secrets;

using System;

public class BitwardenSecretsOptions
{
  public string SessionEnvVarName { get; set; } = StringConstants.BitwardenSessionEnvVarDefault;
  public string BwCliPath { get; set; } = StringConstants.BitwardenCliPathDefault;
  public TimeSpan Timeout { get; set; } = TimeSpan.Parse(StringConstants.BitwardenTimeoutDefault);
  public string DefaultFieldName { get; set; } = "password";
}
