using System;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Executes the Manim Python CLI as a subprocess and returns the path of the
  /// rendered MP4 file.  The Python virtual environment must already be activated
  /// or the <see cref="IManimRunnerOptions.PythonExecutablePath"/> must point to
  /// the venv interpreter directly.
  /// </summary>
  public interface IManimRunner
  {
    /// <summary>
    /// Writes <paramref name="manimCode"/> to a temporary .py file, invokes
    /// <c>manim render</c> via <c>Process.Start</c>, and returns the local path
    /// of the produced MP4 file.
    /// </summary>
    /// <param name="manimCode">A complete, runnable Manim Python scene script.</param>
    /// <param name="sceneId">Used to namespace the temp script and output directory.</param>
    /// <param name="quality">The render quality / resolution tier.</param>
    /// <param name="cancellationToken">Allows the caller to abort the render process.</param>
    /// <returns>Absolute path to the rendered MP4 file.</returns>
    Task<string> RenderAsync(
      string manimCode,
      Guid sceneId,
      ManimQualityEnum quality = ManimQualityEnum.Low480p15,
      CancellationToken cancellationToken = default);
  }
}
