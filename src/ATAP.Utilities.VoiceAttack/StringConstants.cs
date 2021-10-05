

namespace ATAP.Utilities.VoiceAttack {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region Settings File Names
    public const string SettingsFileName = "VoiceAttackSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion

    #region Settings EnvironmentVariable Names
    public const string EnvironmentVariablePrefixConfigRootKey = "ATAP_Utilities_VoiceAttack";
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
    public const string DATE_FORMAT = "0:HH:mm:ss.fff";
    #endregion

    #region Timer Definitions
    public const string MainTimerName = "MainTimer";
    public const string MainTimerTimeSpanConfigRootKey = "MainTimerTimeSpan";
    public const string MainTimerTimeSpanDefault = "0:0:02";
    #endregion
  }
}


namespace ATAP.Utilities.VoiceAttack.AOE {
  public static class StringConstants {

    // ToDo: Localize the string constants
    #region Context Strings
    public const string Context_CreateVillagersLoop_ConfigRootKey = "Context.CreateVillagersLoop";
    public const string Context_CreateVillagersLoop_Default = "CreateVillagersLoop";
    public const string Context_CreateFishingBoatsLoop_ConfigRootKey = "Context.CreateFishingBoatsLoop";
    public const string Context_CreateFishingBoatsLoop_Default = "CreateFishingBoatsLoop";
    #endregion

    #region Data Default values
    public const string VillagerBuildTimeSpanConfigRootKey = "VillagerBuildTimeSpan";
    public const string VillagerBuildTimeSpanDefault = "0:0:20";
    public const string InitialNumVillagersConfigRootKey = "InitialNumVillagers";
    public const string InitialNumVillagersDefault = "3";
    #endregion

    #region Timer Definitions
    public const string CreateVillagersLoopTimerName = "CreateVillagersLoopTimer";
    public const string CreateFishingBoatsLoopTimerName = "CreateFishingBoatsLoopTimer";
    #endregion

  }
}
