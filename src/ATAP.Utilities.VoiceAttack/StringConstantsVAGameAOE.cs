
namespace ATAP.Utilities.VoiceAttack.Game.AOE {
  public static class StringConstants {
    // ToDo: Localize the string constants
    #region Configuration Sections
    #region Settings File name (production)
    public const string SettingsFileName = "VoiceAttackVAGameAOESettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region ConfigurationRoot EnvironmentVariable Prefix
    public const string CustomEnvironmentVariablePrefix = "ATAPUtilitiesVoiceAttackVAGameAOE";
    #endregion
    #endregion

    #region Context Strings
    public const string Context_CreateVillagersLoop_ConfigRootKey = "Context.CreateVillagersLoop";
    public const string Context_CreateVillagersLoop_Default = "Create Villagers Loop";
    public const string Context_CreateFishingBoatsLoop_ConfigRootKey = "Context.CreateFishingBoatsLoop";
    public const string Context_CreateFishingBoatsLoop_Default = "Create Fishing Boats Loop";
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
