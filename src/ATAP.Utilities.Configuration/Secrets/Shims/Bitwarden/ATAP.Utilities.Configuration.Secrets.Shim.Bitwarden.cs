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
    /// Retrieves a field value from the first Bitwarden item matching <paramref name="secretName"/>.
    /// Uses <c>bw list items --search</c> (matching the PowerShell <c>Set-EnvVarsFromBitWarden</c>
    /// pattern) rather than <c>bw get</c>, which requires an exact ID or exact name.
    /// Returns <c>null</c> if no matching item is found, the field is absent, or the CLI exits non-zero.
    /// </summary>
    /// <param name="secretName">Bitwarden vault item search term (e.g. "ProGet_Admin_API_Key").</param>
    /// <param name="fieldName">
    /// Field to retrieve:
    /// <list type="bullet">
    ///   <item><c>"password"</c> — built-in login Password field</item>
    ///   <item><c>"username"</c> — built-in login Username field</item>
    ///   <item><c>"notes"</c> — built-in Notes field</item>
    ///   <item>Any other value — custom field matched by name, case-insensitive</item>
    /// </list>
    /// Defaults to <c>"password"</c>.
    /// </param>
    public async Task<string?> GetSecretAsync(
        string secretName,
        string fieldName = PasswordFieldName,
        CancellationToken cancellationToken = default)
    {
        var (json, exitCode) = await RunBwAsync(["list", "items", "--search", secretName], cancellationToken);
        if (exitCode != 0 || string.IsNullOrWhiteSpace(json))
            return null;

        return ExtractFieldFromSearchResults(json, fieldName);
    }

    /// <summary>
    /// Returns <c>true</c> if at least one Bitwarden item matches <paramref name="secretName"/>
    /// (uses <c>bw list items --search</c>).
    /// </summary>
    public async Task<bool> SecretExistsAsync(
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

    /// <summary>
    /// Parses the JSON array returned by <c>bw list items --search</c>, takes the first
    /// matching item, and extracts the requested field (<c>password</c>, <c>username</c>,
    /// <c>notes</c>, or a custom field by name).
    /// Returns <c>null</c> if the array is empty, the field is absent, or parsing fails.
    /// </summary>
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
        catch (JsonException)
        {
            // Malformed JSON from bw — treat as not found.
        }

        return null;
    }

    private static async Task<(string Output, int ExitCode)> RunBwAsync(
        string[] args, CancellationToken cancellationToken)
    {
        // In agent-spawned shells, process-scope BW_SESSION may be empty; fall back to user scope.
        var sessionKey = Environment.GetEnvironmentVariable("BW_SESSION")
            ?? Environment.GetEnvironmentVariable("BW_SESSION", EnvironmentVariableTarget.User)
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
