using System.Diagnostics;
using System.Runtime.Versioning;
using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[Collection(BwsProcessSecurityCollection.Name)]
public sealed class ConcurrentAndReplacementRaceTests
{
  [Fact]
  public async Task RunAsync_OversizedOutputFailsWithTypedBoundedResult()
  {
    using var harness = new BwsProcessTestHarness(maximumOutputCharacters: 1024);

    var error = await Assert.ThrowsAsync<BwsException>(
      () => harness.Runner.RunAsync(harness.Arguments("dual-stream", "4096")));

    Assert.Equal(BwsFailureKind.CliOutputTooLarge, error.Kind);
    Assert.DoesNotContain(new string('O', 1024), error.ToString(), StringComparison.Ordinal);
    Assert.True(harness.Lease.Disposed);
  }

  [Fact]
  public async Task RunAsync_HungChildTimesOutAndTerminatesItsProcessTree()
  {
    using var harness = new BwsProcessTestHarness(timeoutSeconds: 1);
    var controlFile = TemporaryControlFile("hung");
    try
    {
      var error = await Assert.ThrowsAsync<BwsException>(
        () => harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile)));
      var processIds = await ReadProcessIdsAsync(controlFile);

      Assert.Equal(BwsFailureKind.CliTimeout, error.Kind);
      await AssertProcessesExitedAsync(processIds);
      Assert.True(harness.Lease.Disposed);
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  [Fact]
  public async Task RunAsync_CancellationBeforeDeadlineWinsAndTerminatesTree()
  {
    using var harness = new BwsProcessTestHarness(timeoutSeconds: 10);
    using var cancellation = new CancellationTokenSource();
    var controlFile = TemporaryControlFile("cancel-first");
    try
    {
      var run = harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile), cancellation.Token);
      var processIds = await ReadProcessIdsAsync(controlFile);
      cancellation.Cancel();
      var error = await Assert.ThrowsAsync<BwsException>(() => run);

      Assert.Equal(BwsFailureKind.CliCancelled, error.Kind);
      await AssertProcessesExitedAsync(processIds);
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  [Fact]
  public async Task RunAsync_DeadlineBeforeLateCancellationWinsAndTerminatesTree()
  {
    using var harness = new BwsProcessTestHarness(timeoutSeconds: 1);
    using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(10));
    var controlFile = TemporaryControlFile("timeout-first");
    try
    {
      var run = harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile), cancellation.Token);
      var processIds = await ReadProcessIdsAsync(controlFile);
      var error = await Assert.ThrowsAsync<BwsException>(() => run);

      Assert.Equal(BwsFailureKind.CliTimeout, error.Kind);
      await AssertProcessesExitedAsync(processIds);
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  [Fact]
  public async Task RunAsync_ConcurrentCallersRemainIndependentAndSecretSafe()
  {
    using var harness = new BwsProcessTestHarness();

    var results = await Task.WhenAll(Enumerable.Range(0, 6).Select(
      _ => harness.Runner.RunAsync(harness.Arguments("inspect", BwsProcessTestHarness.SyntheticTokenHash))));

    foreach (var result in results)
    {
      using var report = JsonDocument.Parse(result.StandardOutput);
      Assert.True(report.RootElement.GetProperty("TokenMatched").GetBoolean());
      Assert.False(report.RootElement.GetProperty("ArgumentContainsToken").GetBoolean());
      Assert.DoesNotContain(BwsProcessTestHarness.SyntheticToken, result.StandardOutput, StringComparison.Ordinal);
    }
    Assert.True(harness.Lease.Disposed);
    Assert.Null(Environment.GetEnvironmentVariable(BwsProcessTestHarness.TokenVariable));
  }

  [Fact]
  [SupportedOSPlatform("windows")]
  public async Task AcquireAsync_ReplacementAfterPathValidationFailsClosed()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();
    try
    {
      var tokenPath = fixture.CanonicalPath();
      fixture.WriteEnvelope(tokenPath, fixture.CurrentBinding, token);
      var replacementPath = Path.Combine(Path.GetDirectoryName(tokenPath)!, $"replacement-{Guid.NewGuid():N}.xml");
      File.WriteAllText(replacementPath, "<UnsupportedEnvelope />");
      var validator = new ReplacingSecurityValidator(replacementPath);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(validator: validator, protector: protector).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenFormatUnsupported, error.Kind);
      Assert.True(validator.Replaced);
      Assert.Equal(0, protector.Calls);
      Assert.False(fixture.FileContainsToken(tokenPath, token));
    }
    finally
    {
      Array.Clear(token);
    }
  }

  private static string TemporaryControlFile(string scenario) =>
    Path.Combine(Path.GetTempPath(), $"bws-15-152-d-{scenario}-{Guid.NewGuid():N}.txt");

  private static async Task<int[]> ReadProcessIdsAsync(string controlFile)
  {
    var deadline = Stopwatch.StartNew();
    while (!File.Exists(controlFile) && deadline.Elapsed < TimeSpan.FromSeconds(10)) await Task.Delay(25);
    Assert.True(File.Exists(controlFile));
    return (await File.ReadAllTextAsync(controlFile)).Split(',').Select(int.Parse).ToArray();
  }

  private static async Task AssertProcessesExitedAsync(IEnumerable<int> processIds)
  {
    foreach (var processId in processIds)
    {
      var deadline = Stopwatch.StartNew();
      while (IsRunning(processId) && deadline.Elapsed < TimeSpan.FromSeconds(10)) await Task.Delay(25);
      Assert.False(IsRunning(processId));
    }
  }

  private static bool IsRunning(int processId)
  {
    try
    {
      using var process = Process.GetProcessById(processId);
      return !process.HasExited;
    }
    catch (ArgumentException)
    {
      return false;
    }
  }

  private sealed class ReplacingSecurityValidator(string replacementPath) : IWindowsTokenPathSecurityValidator
  {
    public bool Replaced { get; private set; }

    public void Validate(string directoryPath, string tokenFilePath, string currentSid)
    {
      File.Move(replacementPath, tokenFilePath, overwrite: true);
      Replaced = true;
    }
  }
}
