using System.Diagnostics;
using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class BwsProcessSecurityCollection
{
  public const string Name = "BWS process environment security";
}

[Collection(BwsProcessSecurityCollection.Name)]
public sealed class BwsProcessRunnerSecurityTests
{
  [Fact]
  public async Task RunAsync_ProvidesSyntheticTokenOnlyToDirectChild()
  {
    using var harness = new BwsProcessTestHarness();

    var result = await harness.Runner.RunAsync(harness.Arguments("inspect", BwsProcessTestHarness.SyntheticTokenHash));
    using var report = JsonDocument.Parse(result.StandardOutput);
    var siblingOutput = await harness.RunSiblingInspectAsync();
    using var siblingReport = JsonDocument.Parse(siblingOutput);

    Assert.True(report.RootElement.GetProperty("TokenPresent").GetBoolean());
    Assert.True(report.RootElement.GetProperty("TokenMatched").GetBoolean());
    Assert.False(report.RootElement.GetProperty("ArgumentContainsToken").GetBoolean());
    Assert.Equal([BwsProcessTestHarness.TokenVariable], report.RootElement.GetProperty("SensitiveEnvironmentNames").EnumerateArray().Select(item => item.GetString()));
    Assert.False(siblingReport.RootElement.GetProperty("TokenPresent").GetBoolean());
    Assert.Null(Environment.GetEnvironmentVariable(BwsProcessTestHarness.TokenVariable));
    Assert.True(harness.Lease.Disposed);
    Assert.DoesNotContain(BwsProcessTestHarness.SyntheticToken, result.StandardOutput, StringComparison.Ordinal);
  }

  [Fact]
  public async Task RunAsync_DrainsBothStreamsWithoutDeadlock()
  {
    using var harness = new BwsProcessTestHarness();
    const int charactersPerStream = 256 * 1024;

    var result = await harness.Runner.RunAsync(harness.Arguments("dual-stream", charactersPerStream.ToString(System.Globalization.CultureInfo.InvariantCulture)));

    Assert.Equal(charactersPerStream, result.StandardOutput.Length);
    Assert.All(result.StandardOutput, character => Assert.Equal('O', character));
    Assert.True(harness.Lease.Disposed);
  }

  [Fact]
  public async Task RunAsync_NonzeroFailureSuppressesTokenFromExceptionLogAndResult()
  {
    using var harness = new BwsProcessTestHarness();

    var error = await Assert.ThrowsAsync<BwsException>(() => harness.Runner.RunAsync(harness.Arguments("fail-secret")));
    var diagnostics = string.Join(Environment.NewLine, harness.Logger.Messages.Append(error.ToString()));

    Assert.Equal(BwsFailureKind.CliNonzeroExit, error.Kind);
    Assert.DoesNotContain(BwsProcessTestHarness.SyntheticToken, diagnostics, StringComparison.Ordinal);
    Assert.DoesNotContain("stderr", diagnostics, StringComparison.OrdinalIgnoreCase);
    Assert.True(harness.Lease.Disposed);
    Assert.Null(Environment.GetEnvironmentVariable(BwsProcessTestHarness.TokenVariable));
  }

  [Fact]
  public async Task RunAsync_TimeoutKillsChildProcessTree()
  {
    using var harness = new BwsProcessTestHarness(timeoutSeconds: 1);
    var controlFile = Path.Combine(Path.GetTempPath(), $"bws-test-{Guid.NewGuid():N}.txt");
    try
    {
      var error = await Assert.ThrowsAsync<BwsException>(() => harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile)));
      var processIds = await ReadProcessIdsAsync(controlFile);

      Assert.Equal(BwsFailureKind.CliTimeout, error.Kind);
      await AssertProcessesExitedAsync(processIds);
      Assert.True(harness.Lease.Disposed);
      Assert.Null(Environment.GetEnvironmentVariable(BwsProcessTestHarness.TokenVariable));
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

  [Fact]
  public async Task RunAsync_CancellationKillsChildProcessTree()
  {
    using var harness = new BwsProcessTestHarness();
    using var cancellation = new CancellationTokenSource();
    var controlFile = Path.Combine(Path.GetTempPath(), $"bws-test-{Guid.NewGuid():N}.txt");
    try
    {
      var runTask = harness.Runner.RunAsync(harness.Arguments("hang-tree", controlFile), cancellation.Token);
      var processIds = await ReadProcessIdsAsync(controlFile);
      cancellation.Cancel();
      var error = await Assert.ThrowsAsync<BwsException>(() => runTask);

      Assert.Equal(BwsFailureKind.CliCancelled, error.Kind);
      await AssertProcessesExitedAsync(processIds);
      Assert.True(harness.Lease.Disposed);
      Assert.Null(Environment.GetEnvironmentVariable(BwsProcessTestHarness.TokenVariable));
    }
    finally
    {
      if (File.Exists(controlFile)) File.Delete(controlFile);
    }
  }

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
}
