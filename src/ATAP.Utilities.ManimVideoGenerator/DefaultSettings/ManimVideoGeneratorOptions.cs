using System.ComponentModel.DataAnnotations;

namespace ATAP.Utilities.ManimVideoGenerator
{
  /// <summary>
  /// Strongly-typed options for the ManimVideoGenerator subsystem.
  /// Bound from the "ManimVideoGenerator" configuration section via the Options pattern.
  /// </summary>
  public class ManimVideoGeneratorOptions
  {
    /// <summary>
    /// Path to the Python executable (interpreter inside the venv, or "python" on PATH).
    /// Default: <c>python</c>
    /// </summary>
    [Required]
    public string PythonExecutablePath { get; set; } = StringConstants.PythonExecutablePathDefault;

    /// <summary>
    /// Directory where temporary Manim Python scripts are written before execution.
    /// Default: <c>C:\Temp\ManimVideoGenerator\Scripts</c>
    /// </summary>
    [Required]
    public string TempScriptDirectory { get; set; } = StringConstants.TempScriptDirectoryDefault;

    /// <summary>
    /// Root output directory under which per-scene MP4 files are stored.
    /// Default: <c>C:\Temp\ManimVideoGenerator\Output</c>
    /// </summary>
    [Required]
    public string OutputDirectory { get; set; } = StringConstants.OutputDirectoryDefault;

    /// <summary>
    /// Maximum number of refinement iterations allowed per pipeline stage before
    /// the pipeline gives up and surfaces a failure to the caller.
    /// Default: <c>3</c>
    /// </summary>
    [Range(1, 10)]
    public int MaxRefinementIterations { get; set; } = StringConstants.MaxRefinementIterationsDefault;

    /// <summary>
    /// Default render quality applied when the caller does not specify one.
    /// Default: <see cref="ManimQualityEnum.Low480p15"/>
    /// </summary>
    public ManimQualityEnum DefaultRenderQuality { get; set; } = ManimQualityEnum.Low480p15;
  }
}
