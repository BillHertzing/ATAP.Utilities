using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using ATAP.Utilities.ManimVideoGenerator;

namespace ATAP.Console.ManimDemo;

/// <summary>
/// Interactive background service that drives the Manim demo loop:
///   1. Accept a text prompt describing a new scene (or edits to the current scene).
///   2. Generate (or edit) a Manim Python scene script via <see cref="IAnimationOrchestrator"/>.
///   3. Invoke <c>manim</c> from the project <c>.venv</c> via <see cref="IManimRunner"/>.
///   4. Print the path of the rendered MP4 file.
/// Scenes are written to the <c>ScenesRootPath</c> configured in appsettings / defaults.
/// </summary>
public sealed class ManimDemoBackgroundService : BackgroundService
{
  private readonly IAnimationOrchestrator _orchestrator;
  private readonly IManimRunner _runner;
  private readonly IConfiguration _configuration;
  private readonly IHostApplicationLifetime _lifetime;
  private readonly ILogger<ManimDemoBackgroundService> _logger;

  public ManimDemoBackgroundService(
    IAnimationOrchestrator orchestrator,
    IManimRunner runner,
    IConfiguration configuration,
    IHostApplicationLifetime lifetime,
    ILogger<ManimDemoBackgroundService> logger)
  {
    _orchestrator = orchestrator;
    _runner = runner;
    _configuration = configuration;
    _lifetime = lifetime;
    _logger = logger;
  }

  protected override async Task ExecuteAsync(CancellationToken stoppingToken)
  {
    System.Console.WriteLine(StringConstants.WelcomeMessage);
    System.Console.WriteLine();

    // Resolve scenes root path — populated from appsettings or compile-time default
    var scenesRoot = _configuration[StringConstants.ScenesRootPathConfigRootKey]
      ?? StringConstants.ScenesRootPathDefault;

    var qualityFlag = _configuration[StringConstants.DefaultQualityConfigRootKey]
      ?? StringConstants.DefaultQualityDefault;

    // Map quality flag character to the enum used by IManimRunner
    var quality = qualityFlag switch
    {
      "m" => ManimQualityEnum.Medium720p30,
      "h" => ManimQualityEnum.High1080p60,
      "k" => ManimQualityEnum.Ultra2160p60,
      _ => ManimQualityEnum.Low480p15,      // default: low / preview
    };

    IAnimationScene? currentScene = null;

    while (!stoppingToken.IsCancellationRequested)
    {
      System.Console.WriteLine(StringConstants.PromptInputMessage);
      var input = System.Console.ReadLine();

      if (string.IsNullOrWhiteSpace(input))
        continue;

      if (input.Equals("quit", StringComparison.OrdinalIgnoreCase))
      {
        System.Console.WriteLine(StringConstants.QuitMessage);
        _lifetime.StopApplication();
        return;
      }

      try
      {
        // ── Stage 1: Generate or refine ManimCode via the SK orchestrator ──────────
        System.Console.WriteLine(StringConstants.GeneratingScriptMessage);

        if (currentScene is null)
        {
          // New scene: run the full generation pipeline
          currentScene = await _orchestrator.GenerateAsync(input, stoppingToken)
            .ConfigureAwait(false);
        }
        else
        {
          // Edit mode: incorporate the user's edit instructions into the existing scene
          var editPrompt =
            $"The existing Manim Python scene code is:\n\n{currentScene.ManimCode}\n\n" +
            $"Apply the following editing instructions and return the complete updated scene code:\n\n{input}";

          currentScene = await _orchestrator.GenerateAsync(editPrompt, stoppingToken)
            .ConfigureAwait(false);
        }

        // Persist the generated script to the scenes root directory
        var scriptFileName =
          $"{StringConstants.GeneratedScriptPrefix}{currentScene.Id}{StringConstants.PythonFileExtension}";
        var scriptPath = Path.Combine(scenesRoot, scriptFileName);

        await File.WriteAllTextAsync(scriptPath, currentScene.ManimCode, stoppingToken)
          .ConfigureAwait(false);

        System.Console.WriteLine(string.Format(StringConstants.ScriptGeneratedMessage, scriptPath));

        // ── Stage 2: Render via IManimRunner (Process.Start → manim in .venv) ─────
        System.Console.WriteLine(
          string.Format(StringConstants.RenderingMessage,
            currentScene.Name ?? currentScene.Id.ToString(), qualityFlag));

        var videoPath = await _runner.RenderAsync(
            currentScene.ManimCode,
            currentScene.Id,
            quality,
            stoppingToken)
          .ConfigureAwait(false);

        currentScene.VideoPath = videoPath;
        currentScene.Status = RenderStatusEnum.Ready;

        System.Console.WriteLine(string.Format(StringConstants.RenderCompleteMessage, videoPath));
      }
      catch (OperationCanceledException)
      {
        break;
      }
      catch (Exception ex)
      {
        _logger.LogError(ex, "Manim demo pipeline failed.");
        System.Console.WriteLine(string.Format(StringConstants.RenderFailedMessage, ex.Message));
        currentScene = null;  // Reset — next prompt starts a fresh scene
      }

      // Offer the user a chance to edit the scene before re-rendering
      if (currentScene?.Status == RenderStatusEnum.Ready)
      {
        System.Console.WriteLine(StringConstants.EditPromptMessage);
        var editInput = System.Console.ReadLine();

        if (!string.IsNullOrWhiteSpace(editInput) &&
            !editInput.Equals("done", StringComparison.OrdinalIgnoreCase) &&
            !editInput.Equals("quit", StringComparison.OrdinalIgnoreCase))
        {
          // Loop back — the edit instruction will be picked up at the top of the loop
          // by pushing it back as the next "input"
          // (simple approach: re-run with editInput as prompt)
          System.Console.WriteLine(StringConstants.GeneratingScriptMessage);
          try
          {
            var editPrompt =
              $"The existing Manim Python scene code is:\n\n{currentScene.ManimCode}\n\n" +
              $"Apply the following editing instructions and return the complete updated scene code:\n\n{editInput}";

            currentScene = await _orchestrator.GenerateAsync(editPrompt, stoppingToken)
              .ConfigureAwait(false);

            var videoPath = await _runner.RenderAsync(
                currentScene.ManimCode,
                currentScene.Id,
                quality,
                stoppingToken)
              .ConfigureAwait(false);

            currentScene.VideoPath = videoPath;
            currentScene.Status = RenderStatusEnum.Ready;
            System.Console.WriteLine(string.Format(StringConstants.RenderCompleteMessage, videoPath));
          }
          catch (Exception ex)
          {
            _logger.LogError(ex, "Manim edit/re-render failed.");
            System.Console.WriteLine(string.Format(StringConstants.RenderFailedMessage, ex.Message));
            currentScene = null;
          }
        }
        else if (editInput?.Equals("quit", StringComparison.OrdinalIgnoreCase) == true)
        {
          System.Console.WriteLine(StringConstants.QuitMessage);
          _lifetime.StopApplication();
          return;
        }
      }
    }
  }
}
