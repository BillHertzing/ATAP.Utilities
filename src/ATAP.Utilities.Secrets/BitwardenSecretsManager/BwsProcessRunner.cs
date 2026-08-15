using System.Diagnostics;
using System.Text;
using Microsoft.Extensions.Logging;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed class BwsProcessRunner : IBwsProcessRunner
{
  private readonly BitwardenSecretsManagerOptions _options;
  private readonly IBwsReadOnlyAccessTokenSource _tokenSource;
  private readonly ILogger<BwsProcessRunner> _logger;
  private readonly IBwsExecutableTrustVerifier _executableTrustVerifier;

  public BwsProcessRunner(BitwardenSecretsManagerOptions options, IBwsReadOnlyAccessTokenSource tokenSource, ILogger<BwsProcessRunner> logger, IBwsExecutableTrustVerifier executableTrustVerifier)
  {
    _options = options;
    _tokenSource = tokenSource;
    _logger = logger;
    _executableTrustVerifier = executableTrustVerifier;
    _options.Validate();
  }

  public async Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
  {
    if (Environment.GetEnvironmentVariable("BWS_ACCESS_TOKEN") is not null)
      throw new BwsException(BwsFailureKind.ParentEnvironmentForbidden, "A parent-process BWS_ACCESS_TOKEN is forbidden for application secret access.");

    _executableTrustVerifier.Verify(_options.BwsExecutablePath);

    using var lease = await _tokenSource.AcquireAsync(cancellationToken).ConfigureAwait(false);
    using var process = new Process { StartInfo = new ProcessStartInfo {
      FileName = _options.BwsExecutablePath, UseShellExecute = false,
      RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true } };
    process.StartInfo.Environment.Remove("BWS_ACCESS_TOKEN");
    foreach (var argument in arguments) process.StartInfo.ArgumentList.Add(argument);
    lease.ApplyTo(process.StartInfo);

    try
    {
      if (!process.Start()) throw new BwsException(BwsFailureKind.CliNotFound, "The bws process could not be started.");
      var stdoutTask = DrainAsync(process.StandardOutput, _options.MaximumOutputCharacters, cancellationToken);
      var stderrTask = DrainAsync(process.StandardError, _options.MaximumOutputCharacters, cancellationToken);
      using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(_options.TimeoutSeconds));
      using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeout.Token);
      try { await process.WaitForExitAsync(linked.Token).ConfigureAwait(false); }
      catch (OperationCanceledException) when (timeout.IsCancellationRequested && !cancellationToken.IsCancellationRequested)
      {
        TryKill(process); await IgnoreDrainFailuresAsync(stdoutTask, stderrTask).ConfigureAwait(false);
        throw new BwsException(BwsFailureKind.CliTimeout, "The bws process exceeded its configured timeout.");
      }
      catch (OperationCanceledException)
      {
        TryKill(process); await IgnoreDrainFailuresAsync(stdoutTask, stderrTask).ConfigureAwait(false);
        throw new BwsException(BwsFailureKind.CliCancelled, "The bws process was cancelled.");
      }

      var stdout = await stdoutTask.ConfigureAwait(false);
      var stderr = await stderrTask.ConfigureAwait(false);
      if (stdout.WasTruncated || stderr.WasTruncated)
        throw new BwsException(BwsFailureKind.CliOutputTooLarge, "The bws process output exceeded the configured limit.");
      if (process.ExitCode != 0)
      {
        _logger.LogWarning("bws exited with code {ExitCode}; output was suppressed.", process.ExitCode);
        throw new BwsException(BwsFailureKind.CliNonzeroExit, $"bws exited with code {process.ExitCode}.");
      }
      return new BwsProcessResult(process.ExitCode, stdout.Text);
    }
    catch (BwsException) { throw; }
    catch (Exception exception) when (exception is System.ComponentModel.Win32Exception or InvalidOperationException)
    { throw new BwsException(BwsFailureKind.CliNotFound, "The bws process could not be started.", exception); }
  }

  private static async Task<DrainResult> DrainAsync(StreamReader reader, int maximumCharacters, CancellationToken cancellationToken)
  {
    var buffer = new char[4096]; var builder = new StringBuilder(Math.Min(maximumCharacters, 16 * 1024)); var truncated = false; int read;
    while ((read = await reader.ReadAsync(buffer.AsMemory(), cancellationToken).ConfigureAwait(false)) > 0)
    { var remaining = maximumCharacters - builder.Length; if (remaining > 0) builder.Append(buffer, 0, Math.Min(read, remaining)); truncated |= read > remaining; }
    return new DrainResult(builder.ToString(), truncated);
  }

  private static void TryKill(Process process)
  { try { if (!process.HasExited) process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { } }

  private static async Task IgnoreDrainFailuresAsync(params Task<DrainResult>[] tasks)
  { try { await Task.WhenAll(tasks).ConfigureAwait(false); } catch (OperationCanceledException) { } }

  private sealed record DrainResult(string Text, bool WasTruncated);
}