using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using Microsoft.Extensions.Logging;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

internal sealed class BwsProcessTestHarness : IDisposable
{
  internal const string TokenVariable = "BWS_ACCESS_TOKEN";
  internal const string SyntheticToken = "synthetic-bws-canary-15-152-c";
  private readonly string? _originalParentToken;

  public BwsProcessTestHarness(int timeoutSeconds = 10, int maximumOutputCharacters = 1024 * 1024)
  {
    _originalParentToken = Environment.GetEnvironmentVariable(TokenVariable);
    Environment.SetEnvironmentVariable(TokenVariable, null);
    DotnetPath = Environment.GetEnvironmentVariable("DOTNET_HOST_PATH")
      ?? throw new InvalidOperationException("DOTNET_HOST_PATH was not supplied by the test host.");
    FakeAssemblyPath = Path.Combine(AppContext.BaseDirectory, "BwsProcessTestDouble", "BwsProcessTestDouble.dll");
    Lease = new SyntheticTokenLease(SyntheticToken);
    Logger = new RecordingLogger();
    var options = new BitwardenSecretsManagerOptions
    {
      ApplicationId = "TestApplication",
      ProjectId = "11111111-1111-1111-1111-111111111111",
      ProjectName = "TestProject",
      BwsExecutablePath = DotnetPath,
      TimeoutSeconds = timeoutSeconds,
      MaximumOutputCharacters = maximumOutputCharacters,
    };
    Runner = new BwsProcessRunner(options, new SyntheticTokenSource(Lease), Logger, new RecordingTrustVerifier());
  }

  public string DotnetPath { get; }
  public string FakeAssemblyPath { get; }
  public SyntheticTokenLease Lease { get; }
  public RecordingLogger Logger { get; }
  public BwsProcessRunner Runner { get; }
  public static string SyntheticTokenHash => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(SyntheticToken)));

  public IReadOnlyList<string> Arguments(string mode, params string[] values) => [FakeAssemblyPath, mode, .. values];

  public async Task<string> RunSiblingInspectAsync()
  {
    using var sibling = new Process { StartInfo = new ProcessStartInfo
    {
      FileName = DotnetPath,
      UseShellExecute = false,
      RedirectStandardOutput = true,
      RedirectStandardError = true,
      CreateNoWindow = true,
    } };
    foreach (var argument in Arguments("inspect", SyntheticTokenHash)) sibling.StartInfo.ArgumentList.Add(argument);
    sibling.StartInfo.Environment.Remove(TokenVariable);
    Assert.True(sibling.Start());
    var stdout = sibling.StandardOutput.ReadToEndAsync();
    var stderr = sibling.StandardError.ReadToEndAsync();
    await sibling.WaitForExitAsync();
    Assert.Equal(0, sibling.ExitCode);
    Assert.Equal(string.Empty, await stderr);
    return await stdout;
  }

  public void Dispose() => Environment.SetEnvironmentVariable(TokenVariable, _originalParentToken);

  internal sealed class SyntheticTokenLease(string token) : IBwsAccessTokenLease
  {
    public bool Disposed { get; private set; }
    public void ApplyTo(ProcessStartInfo startInfo) => startInfo.Environment[TokenVariable] = token;
    public void Dispose() => Disposed = true;
  }

  private sealed class SyntheticTokenSource(SyntheticTokenLease lease) : IBwsReadOnlyAccessTokenSource
  {
    public ValueTask<IBwsAccessTokenLease> AcquireAsync(CancellationToken cancellationToken = default)
      => ValueTask.FromResult<IBwsAccessTokenLease>(lease);
  }

  private sealed class RecordingTrustVerifier : IBwsExecutableTrustVerifier
  {
    public void Verify(string executablePath) { }
  }

  internal sealed class RecordingLogger : ILogger<BwsProcessRunner>
  {
    private readonly List<string> _messages = [];
    public IReadOnlyList<string> Messages => _messages;
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
    public bool IsEnabled(LogLevel logLevel) => true;
    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
      => _messages.Add(formatter(state, exception));
  }
}
