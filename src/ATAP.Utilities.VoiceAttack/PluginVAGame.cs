using System;
using System.Collections.Generic;
using System.IO;
using System.Diagnostics;
using System.Timers;
using System.Reflection;

using Serilog;

using Microsoft.Extensions.Configuration;
//using Microsoft.Extensions.Logging;
//using Microsoft.Extensions.Logging.Abstractions;

using System.Reactive;

using CollectionExtensions = ATAP.Utilities.Collection.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;
using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;
using StringConstantsGenericHost = ATAP.Utilities.VoiceAttack.StringConstantsGenericHost;

namespace ATAP.Utilities.VoiceAttack.Game {

  public abstract class Plugin : ATAP.Utilities.VoiceAttack.Plugin {

    public new static ATAP.Utilities.VoiceAttack.Game.IData Data { get; set; }

    public new static string VA_DisplayName() {
      var str = "ATAP Utilities Plugin for VAGames\r\n" + ATAP.Utilities.VoiceAttack.Plugin.VA_DisplayName();
      return str;
    }

    public new static string VA_DisplayInfo() {
      var str = "ATAP Utilities Plugin for Games\r\n\r\n" + ATAP.Utilities.VoiceAttack.Plugin.VA_DisplayInfo();
      return str;
    }
    public new static void VA_Init1(dynamic vaProxy) {
      Serilog.Log.Debug("{0} {1}: VA_Init1 received at {2}", "PluginVAGame", "VA_Init1", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      ATAP.Utilities.VoiceAttack.Plugin.VA_Init1((object)vaProxy);
    }

    public new static void VA_Invoke1(dynamic vaProxy) {

      string iVal = vaProxy.Context;

      Serilog.Log.Debug("{0} {1}: {2} command received at {3}", "PluginVAGame", "VA_Invoke1", iVal, DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      vaProxy.WriteToLog($"{iVal} command received by PluginVAGame  at {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");

      switch (iVal) {
        case StringConstants.Context_StartGame:
          Handle_StartGame();
          break;
        case StringConstants.Context_PauseGame:
          Handle_PauseGame();
          break;
        case StringConstants.Context_ResumeGame:
          Handle_ResumeGame();
          break;
        case StringConstants.Context_RestartGame:
          Handle_RestartGame();
          break;
        case StringConstants.Context_ResignGame:
          Handle_ResignGame();
          break;
        case StringConstants.Context_SaveGame:
          Handle_SaveGame();
          break;
        case StringConstants.Context_QuitGame:
          Handle_QuitGame();
          break;
        default:  //the catch-all for an unrecognized Context is send it down one layer in the plugin stack
          ATAP.Utilities.VoiceAttack.Plugin.VA_Invoke1((object)vaProxy);
          break;
      }
    }

    public static void Handle_StartGame() {
      Data.GameRunning = true;
      Data.StoredVAProxy.Command.Execute("Say Game Started");
    }
    public static void Handle_PauseGame() {
    }
    public static void Handle_ResumeGame() {
    }
    public static void Handle_RestartGame() {
    }
    public static void Handle_ResignGame() {
      Data.GameRunning = false;
    }
    public static void Handle_SaveGame() {
    }
    public static void Handle_QuitGame() {
      Data.GameRunning = false;
    }
    #region Configuration sections
    public static new (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      Serilog.Log.Debug("{0} {1}: GetConfigurationSections Enter at {2}", "PluginVAGame", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));

      (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = ATAP.Utilities.VoiceAttack.Plugin.GetConfigurationSections();
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.AddRange(lDCs);
      SettingsFiles.AddRange(lSFTs);
      CustomEnvironmentVariablePrefixs.AddRange(lEVPs);
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));
      DefaultConfigurations.Add(ATAP.Utilities.VoiceAttack.Game.DefaultConfiguration.Production);

      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

    #region Populate the Data Property
    public static void SetData(IData newData) {
      Serilog.Log.Debug("{0} {1}: SetData Enter at {2}", "PluginVAGame", "SetData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      Data = (Data) newData;
      ATAP.Utilities.VoiceAttack.Plugin.SetData(newData);
    }
    #endregion

    #region Initialize the Data's Autoproperties
    public new static void InitializeData() {
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVAGame", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // ToDo: add parameter tests
      ATAP.Utilities.VoiceAttack.Plugin.InitializeData();
    }
    #endregion

  }
}
