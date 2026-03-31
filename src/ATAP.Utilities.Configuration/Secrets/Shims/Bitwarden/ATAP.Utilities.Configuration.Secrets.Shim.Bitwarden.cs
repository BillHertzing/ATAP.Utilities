using System;
using System.Diagnostics;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Configuration.Secrets.Shims;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// Retrieves secrets directly from the Bitwarden vault via the <c>bw</c> CLI.
/// Requires a valid Bitwarden session key in the <c>BW_SESSION</c> environment variable,
/// which is populated at login by <c>Initialize-BitwardenSession</c> (LoginScript.ps1).
/// </summary>
/// <remarks>
/// <paramref name="secretName"/> is the Bitwarden item name (vault display name).
/// <paramref name="fieldName"/> selects which field to extract:
/// <list type="bullet">
///   <item><c>"password"</c> — built-in Password field (uses <c>bw get password</c>)</item>
///   <item>Any other value — custom field matched by name, case-insensitive
///         (uses <c>bw get item</c> and parses the returned JSON)</item>
/// </list>
/// </remarks>
public sealed class BitwardenSecretsShim : IConfigurationSecretsShim
{
    private const string PasswordFieldName = "password";

    public string ProviderName => "Bitwarden";

    /// <summary>
    /// Retrieves a field value from the Bitwarden item named <paramref name="secretName"/>.
    /// Returns <c>null</c> if the item or field does not exist or the CLI exits non-zero.
    /// </summary>
    /// <param name="secretName">Bitwarden vault item name (e.g. "ProGet_Admin_API_Key").</param>
    /// <param name="fieldName">
    /// Field to retrieve. <c>"password"</c> returns the built-in Password field.
    /// Any other value (e.g. <c>"token"</c>, <c>"key"</c>, <c>"Passphrase"</c>) targets a
    /// custom field by that name (case-insensitive). Defaults to <c>"password"</c>.
    /// </param>
    public async Task<string?> GetSecretAsync(
        string secretName,
        string fieldName = PasswordFieldName,
        CancellationToken cancellationToken = default)
    {
        if (fieldName.Equals(PasswordFieldName, StringComparison.OrdinalIgnoreCase))
        {
            var (output, exitCode) = await RunBwAsync(["get", "password", secretName], cancellationToken);
            return exitCode == 0 ? output : null;
        }

        // For any non-password field: retrieve full item JSON and extract the named custom field.
        var (json, itemExitCode) = await RunBwAsync(["get", "item", secretName], cancellationToken);
        if (itemExitCode != 0 || string.IsNullOrWhiteSpace(json))
            return null;

        return ExtractCustomField(json, fieldName);
    }

    /// <summary>
    /// Returns <c>true</c> if a Bitwarden item named <paramref name="secretName"/> exists
    /// in the vault (exit code 0 from <c>bw get item</c>).
    /// </summary>
    public async Task<bool> SecretExistsAsync(
        string secretName,
        CancellationToken cancellationToken = default)
    {
        var (_, exitCode) = await RunBwAsync(["get", "item", secretName], cancellationToken);
        return exitCode == 0;
    }

    /// <summary>
    /// Parses the JSON returned by <c>bw get item</c> and returns the value of the first
    /// custom field whose name matches <paramref name="fieldName"/> (case-insensitive).
    /// Returns <c>null</c> if the field is not present or the JSON cannot be parsed.
    /// </summary>
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
        catch (JsonException)
        {
            // Malformed JSON from bw — treat as not found.
        }

        return null;
    }

    private static async Task<(string Output, int ExitCode)> RunBwAsync(
        string[] args, CancellationToken cancellationToken)
    {
        var sessionKey = Environment.GetEnvironmentVariable("BW_SESSION")
            ?? throw new InvalidOperationException(
                "BW_SESSION environment variable is not set. " +
                "Run Initialize-BitwardenSession (LoginScript.ps1) before accessing secrets.");

        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "bw",
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

        // Read stdout before waiting to avoid deadlock on full pipe buffers.
        var outputTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
        await process.WaitForExitAsync(cancellationToken);
        var output = await outputTask;

        return (output.Trim(), process.ExitCode);
    }
}
