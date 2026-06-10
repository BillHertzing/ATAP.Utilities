using System;
using System.Threading;
using System.Threading.Tasks;

using Microsoft.Extensions.Logging;

using ATAP.Utilities.ManimVideoGenerator;

namespace ATAP.Console.ManimDemo;

internal sealed class AnimationOrchestrator : IAnimationOrchestrator
{
  private readonly ILogger<AnimationOrchestrator> _logger;

  public AnimationOrchestrator(ILogger<AnimationOrchestrator> logger)
  {
    _logger = logger;
  }

  public Task<IAnimationScene> GenerateAsync(string userPrompt, CancellationToken cancellationToken = default)
  {
    cancellationToken.ThrowIfCancellationRequested();

    var sceneName = string.IsNullOrWhiteSpace(userPrompt)
      ? StringConstants.DefaultSceneClassName
      : StringConstants.DefaultSceneClassName;

    var escapedPrompt = (userPrompt ?? string.Empty)
      .Replace("\\", "\\\\", StringComparison.Ordinal)
      .Replace("\"", "\\\"", StringComparison.Ordinal)
      .Replace("\r", " ", StringComparison.Ordinal)
      .Replace("\n", " ", StringComparison.Ordinal);

    var manimCode =
      "from manim import *\n\n" +
      $"class {sceneName}(Scene):\n" +
      "    def construct(self):\n" +
      $"        caption = Text(\"{escapedPrompt}\")\n" +
      "        caption.scale(0.7)\n" +
      "        self.play(Write(caption))\n" +
      "        self.wait(1)\n";

    var scene = new AnimationScene
    {
      Name = sceneName,
      ManimCode = manimCode,
      Status = RenderStatusEnum.Draft,
      UpdatedAt = DateTime.UtcNow,
    };

    _logger.LogInformation("Generated a default Manim scene template for prompt length {PromptLength}.", escapedPrompt.Length);

    return Task.FromResult<IAnimationScene>(scene);
  }
}
