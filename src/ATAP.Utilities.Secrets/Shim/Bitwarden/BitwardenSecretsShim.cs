namespace ATAP.Utilities.Secrets;

using System;
using System.Diagnostics;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

public sealed class BitwardenSecretsShim : SecretsConfigurableAbstract
{
  private const string PasswordFieldName = "password";
  private readonly BitwardenSecretsOptions _options;

  public BitwardenSecretsShim() : this(new BitwardenSecretsOptions()) { }

  public BitwardenSecretsShim(BitwardenSecretsOptions options)
  {
    _options = options;
  }

  public override string ProviderName => "Bitwarden";

  public override bool IsAvailable() =>
      Environment.GetEnvironmentVariable(_options.SessionEnvVarName) is not null;

  public override async Task<string?> GetSecretAsync(
      string secretName,
      string? fieldName = null,
      CancellationToken cancellationToken = default)
  {
    var field = fieldName ?? _options.DefaultFieldName;
    if (string.Equals(field, PasswordFieldName, StringComparison.OrdinalIgnoreCase))
    {
      var (output, exitCode) = await RunBwAsync(["get", PasswordFieldName, secretName], cancellationToken);
      return exitCode == 0 ? output : null;
    }
    else
    {
      var (output, exitCode) = await RunBwAsync(["get", "item", secretName], cancellationToken);
      return exitCode == 0 ? ExtractCustomField(output, field) : null;
    }
  }

  public override async Task<bool> SecretExistsAsync(
      string secretName,
      CancellationToken cancellationToken = default)
  {
    var (_, exitCode) = await RunBwAsync(["get", "item", secretName], cancellationToken);
    return exitCode == 0;
  }

  private async Task<(string Output, int ExitCode)> RunBwAsync(
      string[] args,
      CancellationToken cancellationToken)
  {
    var sessionKey = Environment.GetEnvironmentVariable(_options.SessionEnvVarName)
        ?? throw new InvalidOperationException(StringConstants.ExceptionBwSessionNotSet);

    using var process = new Process
    {
      StartInfo = new ProcessStartInfo
      {
        FileName = _options.BwCliPath,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false,
        CreateNoWindow = true,
      }
    };

    foreach (var arg in args)
      process.StartInfo.ArgumentList.Add(arg);

    process.StartInfo.ArgumentList.Add("--session");
    process.StartInfo.ArgumentList.Add(sessionKey);

    process.Start();

    using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    cts.CancelAfter(_options.Timeout);

    var outputTask = process.StandardOutput.ReadToEndAsync(cts.Token);
    await process.WaitForExitAsync(cts.Token);
    var output = await outputTask;

    return (output.Trim(), process.ExitCode);
  }

  private static string? ExtractCustomField(string json, string fieldName)
  {
    try
    {
      using var doc = JsonDocument.Parse(json);
      if (!doc.RootElement.TryGetProperty("fields", out var fields))
        return null;

      foreach (var field in fields.EnumerateArray())
      {
        if (field.TryGetProperty("name", out var name) &&
            name.GetString()?.Equals(fieldName, StringComparison.OrdinalIgnoreCase) == true &&
            field.TryGetProperty("value", out var value))
        {
          return value.GetString();
        }
      }
    }
    catch (JsonException) { }

    return null;
  }
}
