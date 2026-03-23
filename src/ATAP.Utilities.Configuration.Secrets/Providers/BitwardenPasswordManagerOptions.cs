namespace ATAP.Utilities.Configuration.Secrets.Providers;

/// <summary>
/// Options for the Bitwarden Password Manager provider.
/// </summary>
public sealed class BitwardenPasswordManagerOptions
{
  /// <summary>
  /// Name of the environment variable that holds the active Bitwarden CLI session token.
  /// Defaults to <c>BW_SESSION</c>. The session token is obtained by running
  /// <c>bw unlock --raw</c> and assigning the output to this variable.
  /// </summary>
  public string SessionEnvVarName { get; set; } = "BW_SESSION";

  /// <summary>
  /// Absolute path to the <c>bw</c> CLI executable.
  /// When null, the executable is resolved via the PATH environment variable.
  /// </summary>
  public string? BwCliPath { get; set; }

  /// <summary>
  /// Timeout applied to each individual <c>bw</c> CLI invocation.
  /// Defaults to 10 seconds.
  /// </summary>
  public TimeSpan Timeout { get; set; } = TimeSpan.FromSeconds(10);
}
