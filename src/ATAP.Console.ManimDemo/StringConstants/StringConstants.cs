namespace ATAP.Console.ManimDemo;

public static class StringConstants
{
  #region ConfigRootKeys
  public const string ManimDemoConfigRootKey = "ManimDemo";
  public const string ScenesRootPathConfigRootKey = "ManimDemo:ScenesRootPath";
  public const string VenvPathConfigRootKey = "ManimDemo:VenvPath";
  public const string DefaultQualityConfigRootKey = "ManimDemo:DefaultQuality";
  #endregion

  #region Default Values
  public const string ScenesRootPathDefault =
    @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-96-sprint-0005-work-items\ManimVideoGenerator";
  public const string VenvPathDefault =
    @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-96-sprint-0005-work-items\ManimVideoGenerator\.venv";
  public const string DefaultQualityDefault = "l";
  #endregion

  #region Console Messages
  public const string WelcomeMessage = "ATAP Manim Demo — AI-Assisted Animation Generator";
  public const string PromptInputMessage = "Enter a scene description (or 'quit' to exit):";
  public const string GeneratingScriptMessage = "Generating Manim script from prompt...";
  public const string RenderingMessage = "Rendering scene '{0}' at quality '{1}'...";
  public const string RenderCompleteMessage = "Render complete. Output: {0}";
  public const string RenderFailedMessage = "Render failed: {0}";
  public const string EditPromptMessage = "Enter edit instructions for the scene (or 'done' to re-render, 'quit' to exit):";
  public const string ScriptGeneratedMessage = "Script generated at: {0}";
  public const string QuitMessage = "Exiting Manim Demo.";
  #endregion

  #region Manim CLI
  public const string ManimExecutableRelativePath = @"Scripts\manim.exe";
  public const string ManimRenderArgs = "render -q{0} \"{1}\" {2}";
  public const string DefaultSceneClassName = "GeneratedScene";
  #endregion

  #region File Naming
  public const string GeneratedScriptPrefix = "scene_";
  public const string PythonFileExtension = ".py";
  public const string VideoFileExtension = ".mp4";
  #endregion
}
