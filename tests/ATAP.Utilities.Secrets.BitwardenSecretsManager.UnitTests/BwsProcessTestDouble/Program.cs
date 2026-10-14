using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

const string tokenVariable = "BWS_ACCESS_TOKEN";
var mode = args.FirstOrDefault() ?? throw new ArgumentException("A test-double mode is required.");

switch (mode)
{
  case "inspect":
  {
    var expectedHash = args[1];
    var token = Environment.GetEnvironmentVariable(tokenVariable);
    var actualHash = token is null ? null : Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    var report = new
    {
      TokenPresent = token is not null,
      TokenMatched = string.Equals(actualHash, expectedHash, StringComparison.Ordinal),
      ArgumentContainsToken = token is not null && args.Any(argument => argument.Contains(token, StringComparison.Ordinal)),
      SensitiveEnvironmentNames = Environment.GetEnvironmentVariables().Keys.Cast<object>()
        .Select(key => key.ToString())
        .Where(key => string.Equals(key, tokenVariable, StringComparison.Ordinal))
        .ToArray(),
    };
    Console.Write(JsonSerializer.Serialize(report));
    break;
  }
  case "dual-stream":
  {
    var count = int.Parse(args[1], System.Globalization.CultureInfo.InvariantCulture);
    var stdout = Console.Out.WriteAsync(new string('O', count));
    var stderr = Console.Error.WriteAsync(new string('E', count));
    await Task.WhenAll(stdout, stderr);
    break;
  }
  case "fail-secret":
    Console.Error.Write(Environment.GetEnvironmentVariable(tokenVariable));
    Environment.ExitCode = 23;
    break;
  case "hang-tree":
  {
    var controlFile = args[1];
    using var descendant = Process.Start(new ProcessStartInfo
    {
      FileName = Environment.ProcessPath!,
      UseShellExecute = false,
      CreateNoWindow = true,
    }.WithArguments(typeof(ProcessStartInfoExtensions).Assembly.Location, "leaf"))!;
    await File.WriteAllTextAsync(controlFile, $"{Environment.ProcessId},{descendant.Id}");
    await Task.Delay(Timeout.InfiniteTimeSpan);
    break;
  }
  case "leaf":
    await Task.Delay(Timeout.InfiniteTimeSpan);
    break;
  default:
    throw new ArgumentOutOfRangeException(nameof(mode), mode, "Unknown test-double mode.");
}

internal static class ProcessStartInfoExtensions
{
  public static ProcessStartInfo WithArguments(this ProcessStartInfo startInfo, params string[] arguments)
  {
    foreach (var argument in arguments) startInfo.ArgumentList.Add(argument);
    return startInfo;
  }
}
