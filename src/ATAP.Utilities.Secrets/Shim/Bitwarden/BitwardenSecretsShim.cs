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
    var field = fieldName
        ?? (secretName.StartsWith("dbConnectionString", StringComparison.OrdinalIgnoreCase) ? "notes" : _options.DefaultFieldName);
    var (json, exitCode) = await RunBwAsync(["list", "items", "--search", secretName], cancellationToken);
    if (exitCode != 0 || string.IsNullOrWhiteSpace(json))
      return null;

    return ExtractFieldFromSearchResults(json, field);
  }

  public override async Task<bool> SecretExistsAsync(
      string secretName,
      CancellationToken cancellationToken = default)
  {
    var (json, exitCode) = await RunBwAsync(["list", "items", "--search", secretName], cancellationToken);
    if (exitCode != 0 || string.IsNullOrWhiteSpace(json))
      return false;

    try
    {
      using var doc = JsonDocument.Parse(json);
      return doc.RootElement.ValueKind == JsonValueKind.Array &&
             doc.RootElement.GetArrayLength() > 0;
    }
    catch (JsonException)
    {
      return false;
    }
  }

  private async Task<(string Output, int ExitCode)> RunBwAsync(
      string[] args,
      CancellationToken cancellationToken)
  {
    // In agent-spawned shells, process-scope BW_SESSION may be empty; fall back to user scope.
    var sessionKey = Environment.GetEnvironmentVariable(_options.SessionEnvVarName)
        ?? Environment.GetEnvironmentVariable(_options.SessionEnvVarName, EnvironmentVariableTarget.User)
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

  private static string? ExtractFieldFromSearchResults(string json, string fieldName)
  {
    try
    {
      using var doc = JsonDocument.Parse(json);
      if (doc.RootElement.ValueKind != JsonValueKind.Array ||
          doc.RootElement.GetArrayLength() == 0)
        return null;

      var item = doc.RootElement[0];

      if (fieldName.Equals(PasswordFieldName, StringComparison.OrdinalIgnoreCase))
      {
        if (item.TryGetProperty("login", out var login) &&
            login.TryGetProperty("password", out var password))
          return password.GetString();
        return null;
      }

      if (fieldName.Equals("username", StringComparison.OrdinalIgnoreCase))
      {
        if (item.TryGetProperty("login", out var login) &&
            login.TryGetProperty("username", out var username))
          return username.GetString();
        return null;
      }

      if (fieldName.Equals("notes", StringComparison.OrdinalIgnoreCase))
      {
        if (item.TryGetProperty("notes", out var notes))
          return notes.GetString()?.Trim();
        return null;
      }

      // Custom field — search item.fields array case-insensitively.
      if (item.TryGetProperty("fields", out var fields))
      {
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
    }
    catch (JsonException) { }

    return null;
  }
}
