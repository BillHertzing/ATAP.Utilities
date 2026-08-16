using System.Diagnostics;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[Collection(BwsProcessSecurityCollection.Name)]
public sealed class ProcessRunnerFailureTests
{
  [Fact]
  public async Task RunAsync_MissingExecutable_ThrowsCliNotFoundAndDisposesLease()
  {
    var lease = new RecordingLease();
    var options = ValidOptions(Path.Combine(Path.GetTempPath(), $"missing-bws-{Guid.NewGuid():N}.exe"));
    var runner = new BwsProcessRunner(
      options,
      new RecordingTokenSource(lease),
      new BwsProcessTestHarness.RecordingLogger(),
      new AcceptingTrustVerifier());

    var error = await Assert.ThrowsAsync<BwsException>(() => runner.RunAsync(["secret", "list"]));

    Assert.Equal(BwsFailureKind.CliNotFound, error.Kind);
    Assert.True(lease.Disposed);
    Assert.IsType<System.ComponentModel.Win32Exception>(error.InnerException);
  }

  [Fact]
  public async Task RunAsync_NonzeroExit_ThrowsCliNonzeroExitWithoutRawOutput()
  {
    using var harness = new BwsProcessTestHarness();

    var error = await Assert.ThrowsAsync<BwsException>(() => harness.Runner.RunAsync(harness.Arguments("fail-secret")));

    Assert.Equal(BwsFailureKind.CliNonzeroExit, error.Kind);
    Assert.DoesNotContain(BwsProcessTestHarness.SyntheticToken, error.ToString(), StringComparison.Ordinal);
    Assert.True(harness.Lease.Disposed);
  }

  [Fact]
  public async Task RunAsync_HungChild_ThrowsCliTimeout()
  {
    using var harness = new BwsProcessTestHarness(timeoutSeconds: 1);
    var controlFile = Path.Combine(Path.GetTempPath(), $"bws-timeout-{Guid.NewGuid():N}.txt");
    try
    {
      var error = await Assert.ThrowsAsync<BwsException>(() => harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile)));

      Assert.Equal(BwsFailureKind.CliTimeout, error.Kind);
      Assert.True(harness.Lease.Disposed);
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  [Fact]
  public async Task RunAsync_CancelledCall_ThrowsCliCancelled()
  {
    using var harness = new BwsProcessTestHarness();
    using var cancellation = new CancellationTokenSource();
    var controlFile = Path.Combine(Path.GetTempPath(), $"bws-cancel-{Guid.NewGuid():N}.txt");
    try
    {
      var run = harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile), cancellation.Token);
      await WaitForFileAsync(controlFile);

      cancellation.Cancel();
      var error = await Assert.ThrowsAsync<BwsException>(() => run);

      Assert.Equal(BwsFailureKind.CliCancelled, error.Kind);
      Assert.True(harness.Lease.Disposed);
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  private static async Task WaitForFileAsync(string path)
  {
    var elapsed = Stopwatch.StartNew();
    while (!File.Exists(path) && elapsed.Elapsed < TimeSpan.FromSeconds(10)) await Task.Delay(25);
    Assert.True(File.Exists(path), "The deterministic child did not report readiness.");
  }

  private static BitwardenSecretsManagerOptions ValidOptions(string executablePath) => new()
  {
    ApplicationId = "TestApplication",
    ProjectId = "11111111-1111-1111-1111-111111111111",
    ProjectName = "TestProject",
    BwsExecutablePath = executablePath,
  };

  private sealed class RecordingTokenSource(RecordingLease lease) : IBwsReadOnlyAccessTokenSource
  {
    public ValueTask<IBwsAccessTokenLease> AcquireAsync(CancellationToken cancellationToken = default) =>
      ValueTask.FromResult<IBwsAccessTokenLease>(lease);
  }

  private sealed class RecordingLease : IBwsAccessTokenLease
  {
    public bool Disposed { get; private set; }
    public void ApplyTo(ProcessStartInfo startInfo) => startInfo.Environment["BWS_ACCESS_TOKEN"] = "synthetic-process-value";
    public void Dispose() => Disposed = true;
  }

  private sealed class AcceptingTrustVerifier : IBwsExecutableTrustVerifier
  {
    public void Verify(string executablePath) { }
  }
}
