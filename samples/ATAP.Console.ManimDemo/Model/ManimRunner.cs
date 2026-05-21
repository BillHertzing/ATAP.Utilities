using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using ATAP.Utilities.ManimVideoGenerator;

namespace ATAP.Console.ManimDemo;

internal sealed class ManimRunner : IManimRunner
{
  private readonly IOptions<ManimVideoGeneratorOptions> _options;
  private readonly ILogger<ManimRunner> _logger;

  public ManimRunner(IOptions<ManimVideoGeneratorOptions> options, ILogger<ManimRunner> logger)
  {
    _options = options;
    _logger = logger;
  }

  public async Task<string> RenderAsync(
    string manimCode,
    Guid sceneId,
    ManimQualityEnum quality = ManimQualityEnum.Low480p15,
    CancellationToken cancellationToken = default)
  {
    cancellationToken.ThrowIfCancellationRequested();

    var opts = _options.Value;
    Directory.CreateDirectory(opts.TempScriptDirectory);
    Directory.CreateDirectory(opts.OutputDirectory);

    var sceneClassName = $"{StringConstants.DefaultSceneClassName}{sceneId:N}";
    var scriptPath = Path.Combine(opts.TempScriptDirectory, $"scene_{sceneId:N}.py");
    var rewrittenScript = RewriteSceneClassName(manimCode, sceneClassName);
    await File.WriteAllTextAsync(scriptPath, rewrittenScript, cancellationToken).ConfigureAwait(false);

    var qualityFlag = quality switch
    {
      ManimQualityEnum.Low480p15 => "l",
      ManimQualityEnum.Medium720p30 => "m",
      ManimQualityEnum.High1080p60 => "h",
      ManimQualityEnum.Ultra2160p60 => "k",
      _ => "l",
    };

    var startInfo = new ProcessStartInfo
    {
      FileName = opts.PythonExecutablePath,
      Arguments = $"-m manim render -q{qualityFlag} --media_dir \"{opts.OutputDirectory}\" \"{scriptPath}\" {sceneClassName}",
      RedirectStandardOutput = true,
      RedirectStandardError = true,
      UseShellExecute = false,
      CreateNoWindow = true,
    };

    using var process = new Process { StartInfo = startInfo };
    process.Start();

    var stdoutTask = process.StandardOutput.ReadToEndAsync(cancellationToken);
    var stderrTask = process.StandardError.ReadToEndAsync(cancellationToken);
    await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);

    var stdout = await stdoutTask.ConfigureAwait(false);
    var stderr = await stderrTask.ConfigureAwait(false);

    if (process.ExitCode != 0)
    {
      _logger.LogError("manim invocation failed with exit code {ExitCode}. stderr: {Stderr}", process.ExitCode, stderr);
      throw new InvalidOperationException($"manim render failed with exit code {process.ExitCode}: {stderr}");
    }

    _logger.LogInformation("manim render succeeded for scene {SceneId}. stdout: {Stdout}", sceneId, stdout);

    return FindRenderedVideoPath(opts.OutputDirectory, sceneClassName)
      ?? throw new FileNotFoundException("manim completed successfully, but no MP4 output was found.", opts.OutputDirectory);
  }

  private static string RewriteSceneClassName(string manimCode, string sceneClassName)
  {
    if (string.IsNullOrWhiteSpace(manimCode))
    {
      return
        "from manim import *\n\n" +
        $"class {sceneClassName}(Scene):\n" +
        "    def construct(self):\n" +
        "        self.play(Write(Text(\"Generated scene\")))\n";
    }

    return manimCode.Replace(
      $"class {StringConstants.DefaultSceneClassName}(Scene):",
      $"class {sceneClassName}(Scene):",
      StringComparison.Ordinal);
  }

  private static string? FindRenderedVideoPath(string outputRoot, string sceneClassName)
  {
    if (!Directory.Exists(outputRoot))
    {
      return null;
    }

    foreach (var file in Directory.EnumerateFiles(outputRoot, $"{sceneClassName}.mp4", SearchOption.AllDirectories))
    {
      return file;
    }

    return null;
  }
}
