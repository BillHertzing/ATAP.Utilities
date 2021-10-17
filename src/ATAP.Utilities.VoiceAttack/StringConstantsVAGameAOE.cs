
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

    #region Phrases To Say
      public const string Say_First_Six_Villagers_on_Sheep = "First Six Villagers on Sheep";
      public const string Say_Next_Four_Villagers_on_Wood = "Next Four Villagers on Wood";
      public const string Say_Next_To_Berries_Build_House_Build_Mill = "Next To Berries, Build House, Build Mill";
      public const string Say_Next_Two_Villagers_To_Berries = "Next Two Villagers To Berries";
      public const string Say_Wood_Villager_Build_House = "Wood Villager Build House";
      public const string Say_Next_Villager_Lure_Boar = "Next Villager Lure Boar";
      public const string Say_Next_Two_Villagers_To_Boar = "Next Two Villagers To Boar";
      public const string Say_Next_Three_Villagers_To_Wood = "Next Three Villagers To Wood";
      public const string Say_Next_Villager_To_Sheep = "Next Villager To Sheep";

    #endregion

    #region VA Commands for this profile
      public const string Command_Create_Villagers_In_One_Limit_22 = "Create Villagers In One Limit 22";

    #endregion

  }
}
