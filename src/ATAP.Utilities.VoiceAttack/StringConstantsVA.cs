
namespace ATAP.Utilities.VoiceAttack {
  public static class StringConstantsVA {
    // ToDo: Localize the string constants
    #region Configuration Sections
    #region Settings File name (production)
    public const string SettingsFileName = "VoiceAttackVASettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region ConfigurationRoot EnvironmentVariable Prefix
    public const string CustomEnvironmentVariablePrefix = "ATAPUtilitiesVoiceAttackVA";
    #endregion
    #endregion

    #region Debugging tools
    public const string Debug = "Debug";
    #endregion

    #region Exception Messages (string constants)
    public const string StartExceptionMessage = "ATAP.Utilities.VoiceAttackStartupException";
    public const string KillExceptionMessage = "ATAP.Utilities.VoiceAttackKillException";
    #endregion

    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\VoiceAttack\\";
    #endregion

    #region Plugins subdirecotry
    public const string PluginPathBaseConfigRootKey = "VoiceAttackPluginPathBase";
    public const string PluginPathBaseDefault = "C:\\Program Files\\VoiceAttack\\Apps\\VoiceAttack\\";
    #endregion

    #region ToDo migrate to an ATAP Abstract class for Progress,and its stringconstants assembly
    public const string EnableProgressConfigRootKey = "EnableProgress";
    public const string EnableProgressDefault = "true";
    #endregion
    #region Persistence directory
    public const string PersistencePathBaseDefault = "D:\\Temp\\VoiceAttack\\SerializedObjects\\";
    public const string PersistencePathBaseConfigRootKey = "PersistencePathBase";
    #endregion

    #region VoiceAttack Configuration Root Keys and Default values
    public const string ProfileConfigRootKey = "VoiceAttackProfile";
    public const string ProfileNameDefault = "ATAP.Utilities.VoiceAttack";
    #endregion

    #region FormatStrings
    public const string DATE_FORMAT = "HH:mm:ss.fff";
    #endregion

    #region Timer Definitions
    public const string MainTimerName = "MainTimer";
    public const string MainTimerTimeSpanConfigRootKey = "MainTimerTimeSpan";
    public const string MainTimerTimeSpanDefault = "0:0:02";
    #endregion

    #region Queue Definitions
    public const string MainQueueName = "MainQueue";
    #endregion
  }
}
