namespace ATAP.Utilities.ManimVideoGenerator
{
  public static class StringConstants
  {
    #region Settings File Names
    public const string SettingsFileName = "ATAP.Utilities.ManimVideoGenerator.Settings";
    public const string SettingsFileNameSuffix = "json";
    #endregion

    #region ConfigRootKeys
    public const string ManimVideoGeneratorConfigRootKey = "ManimVideoGenerator";
    public const string PythonExecutablePathConfigRootKey = "ManimVideoGenerator:PythonExecutablePath";
    public const string VenvActivateScriptPathConfigRootKey = "ManimVideoGenerator:VenvActivateScriptPath";
    public const string TempScriptDirectoryConfigRootKey = "ManimVideoGenerator:TempScriptDirectory";
    public const string OutputDirectoryConfigRootKey = "ManimVideoGenerator:OutputDirectory";
    public const string MaxRefinementIterationsConfigRootKey = "ManimVideoGenerator:MaxRefinementIterations";
    public const string DefaultRenderQualityConfigRootKey = "ManimVideoGenerator:DefaultRenderQuality";
    #endregion

    #region Default Values
    public const string PythonExecutablePathDefault = "python";
    public const string TempScriptDirectoryDefault = "C:\\Temp\\ManimVideoGenerator\\Scripts";
    public const string OutputDirectoryDefault = "C:\\Temp\\ManimVideoGenerator\\Output";
    public const int MaxRefinementIterationsDefault = 3;
    #endregion

    #region Agent Names
    public const string QueryValidatorAgentName = "QueryValidator";
    public const string DescriptionExpanderAgentName = "DescriptionExpander";
    public const string DescriptionRefinerAgentName = "DescriptionRefiner";
    public const string DescriptionValidatorAgentName = "DescriptionValidator";
    public const string CodeGeneratorAgentName = "CodeGenerator";
    public const string CodeValidatorAgentName = "CodeValidator";
    #endregion

    #region Agent Approval Keywords
    public const string ApprovedVerdict = "APPROVED";
    public const string RejectedVerdict = "REJECTED";
    #endregion

    #region Render Output
    public const string ManimVideoFileExtension = ".mp4";
    public const string ManimMediaSubDirectory = "media";
    public const string ManimVideosSubDirectory = "videos";
    #endregion
  }
}
