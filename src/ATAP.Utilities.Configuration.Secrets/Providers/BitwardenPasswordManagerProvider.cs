using System.Diagnostics;
using System.Text.Json;

namespace ATAP.Utilities.Configuration.Secrets.Providers;

/// <summary>
/// Secret provider that retrieves items from the Bitwarden Password Manager
/// via the official <c>bw</c> CLI.
/// </summary>
/// <remarks>
/// Requires an active Bitwarden session before application startup:
/// <code>$env:BW_SESSION = (bw unlock --raw)</code>
/// The session variable name is configurable via <see cref="BitwardenPasswordManagerOptions.SessionEnvVarName"/>.
/// </remarks>
public sealed class BitwardenPasswordManagerProvider : ISecretProvider
{
  private readonly BitwardenPasswordManagerOptions _opts;

  /// <summary>Initializes a new instance with the supplied options.</summary>
  public BitwardenPasswordManagerProvider(BitwardenPasswordManagerOptions opts) => _opts = opts;

  /// <inheritdoc />
  public string ProviderName => "BitwardenPasswordManager";

  /// <inheritdoc />
  /// <remarks>Returns true when the session environment variable is set and non-empty.</remarks>
  public bool IsAvailable() =>
    !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(_opts.SessionEnvVarName));

  /// <inheritdoc />
  /// <remarks>
  /// When <paramref name="fieldName"/> is null or "password" the fast
  /// <c>bw get password &lt;name&gt;</c> sub-command is used.
  /// For any other field name the full item JSON is retrieved and the matching
  /// custom field is extracted.
  /// </remarks>
  public async Task<string?> GetSecretAsync(
    string secretName, string? fieldName, CancellationToken cancellationToken = default)
  {
    var session = Environment.GetEnvironmentVariable(_opts.SessionEnvVarName)
      ?? throw new InvalidOperationException(
           $"Bitwarden session variable '{_opts.SessionEnvVarName}' is not set. " +
           "Run 'bw unlock --raw' and assign the output to the variable before starting.");

    bool usePasswordSubCommand =
      string.IsNullOrWhiteSpace(fieldName) || fieldName == "password";

    string arguments = usePasswordSubCommand
      ? $"get password \"{secretName}\""
      : $"get item \"{secretName}\"";

    var psi = new ProcessStartInfo
    {
      FileName             = _opts.BwCliPath ?? "bw",
      Arguments            = arguments,
      RedirectStandardOutput = true,
      RedirectStandardError  = true,
      UseShellExecute        = false,
      CreateNoWindow         = true,
    };
    psi.Environment[_opts.SessionEnvVarName] = session;

    using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    cts.CancelAfter(_opts.Timeout);

    using var process = Process.Start(psi)
      ?? throw new InvalidOperationException("Failed to start the bw CLI process.");

    var outputTask = process.StandardOutput.ReadToEndAsync(cts.Token);
    var errorTask  = process.StandardError.ReadToEndAsync(cts.Token);

    await process.WaitForExitAsync(cts.Token);

    var output = await outputTask;
    var error  = await errorTask;

    if (process.ExitCode != 0)
      throw new InvalidOperationException(
        $"bw CLI exited {process.ExitCode} while fetching '{secretName}': {error.Trim()}");

    if (usePasswordSubCommand)
      return output.Trim();

    return ExtractCustomField(output, fieldName!);
  }

  private static string? ExtractCustomField(string itemJson, string fieldName)
  {
    using var doc = JsonDocument.Parse(itemJson);
    if (!doc.RootElement.TryGetProperty("fields", out var fields))
      return null;

    foreach (var field in fields.EnumerateArray())
    {
      if (field.TryGetProperty("name",  out var name)  &&
          field.TryGetProperty("value", out var value) &&
          string.Equals(name.GetString(), fieldName, StringComparison.OrdinalIgnoreCase))
      {
        return value.GetString();
      }
    }

    return null;
  }
}
