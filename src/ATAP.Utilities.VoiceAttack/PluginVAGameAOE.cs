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

using ATAP.Utilities.HostedServices;


using CollectionExtensions = ATAP.Utilities.Collection.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;

using StringConstantsVAGame = ATAP.Utilities.VoiceAttack.Game.StringConstants;
using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;
using StringConstantsGenericHost = ATAP.Utilities.VoiceAttack.StringConstantsGenericHost;


namespace ATAP.Utilities.VoiceAttack.Game.AOE {

  public abstract class Plugin : ATAP.Utilities.VoiceAttack.Game.Plugin {

    public new static ATAP.Utilities.VoiceAttack.Game.AOE.IData Data { get; set; }


    public new static string VA_DisplayName() {
      var str = "ATAP Utilities Plugin for Age Of Empires\r\n" + ATAP.Utilities.VoiceAttack.Game.Plugin.VA_DisplayName();
      return str;
    }

    public new static string VA_DisplayInfo() {
      var str = "ATAP Utilities Plugin VAGameAOE\r\n\r\n" + ATAP.Utilities.VoiceAttack.Game.Plugin.VA_DisplayInfo();
      return str;
    }

    public new static void VA_Init1(dynamic vaProxy) {
      Serilog.Log.Debug("{0} {1}: VA_Init1 received at {2}", "PluginVAGameAOE", "VA_Init1", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      ATAP.Utilities.VoiceAttack.Game.Plugin.VA_Init1((object)vaProxy);
    }

    public new static void VA_Invoke1(dynamic vaProxy) {

      string iVal = vaProxy.Context;

      Serilog.Log.Debug("{0} {1}: {2} command received at {3}", "PluginVAGameAOE", "VA_Invoke1", iVal, DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      vaProxy.WriteToLog($"{iVal} command received by PluginVAGameAOE at {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");

      switch (iVal) {
        case StringConstants.Context_CreateVillagersLoop_Default:
          int upperLimit = 26; // ToDo set int in command, read int from proxy
          int numStructures = 1; // ToDo set int in command, read int from proxy
          Handle_CreateVillagersLoop(upperLimit, numStructures);
          break;
        case StringConstants.Context_CreateFishingBoatsLoop_Default:
          vaProxy.WriteToLog($"Create CreateFishingBoatsLoop Loops started {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");
          break;
        default:  //the catch-all for an unrecognized Context is send it down one layer in the plugin stack
          ATAP.Utilities.VoiceAttack.Game.Plugin.VA_Invoke1((object)vaProxy);
          break;
      }
    }

    ///////////////////////////////


    private static void Handle_CreateVillagersLoop(int upperLimit, int numTownCenters) {

      if (Data.TimerDisposeHandles.ContainsKey(StringConstants.CreateVillagersLoopTimerName)) {
        // Timer already exists, write to log

        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles already contains a not-null DisposeHandle for {2}", "Plugin", "Handle_CreateVillagersLoop", StringConstants.CreateVillagersLoopTimerName);

        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles already contains a not-null DisposeHandle for {StringConstants.CreateVillagersLoopTimerName}", "Blue");

        // ToDo: set upperLimit and numTownCenters somewhere
        //Data.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].Timer.Enabled = true;
      }
      else {
        // Duration is from Data configuration
        var durationAsString = Data.CurrentVillagerBuildTimeSpan;
        Data.TimerDisposeHandles.Add(StringConstants.CreateVillagersLoopTimerName, new ObservableResetableTimer(Data.CurrentVillagerBuildTimeSpan,
  new Action(() => {
    // Handle the timer event in this lambda Action. This lambda closes over a local variable set to the value of numTownCenters, and another which counts the number of villagers created in this loop, and the upperLimiit parameter
    // This lambda writes to the dynamic StoredVAProxy Command
    // This lambda calls another command to stop the loop when the upperlimit of villagers has been built

    // Serilog.Log.Debug("{0} {1}: The CreateVillagersLoopObservableResetableTimer fired at {2}", "Plugin", "OnCreateVillagersLoopObservableResetableTimerEvent", e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT));
    // StoredVAProxy.Command.WriteToLog($"The CreateVillagersLoopObservableResetableTimer fired at {e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT)}", "Blue");
    Serilog.Log.Debug("{0} {1}: The {2}} fired", "Plugin", "CreateVillagersLoopTimer", StringConstants.CreateVillagersLoopTimerName);
    Data.StoredVAProxy.Command.WriteToLog($"The {StringConstants.CreateVillagersLoopTimerName} fired", "Purple");
    //  numVillagersBuiltInThisLoop += numTownCenters; // ToDo: account for non zero upperlimit mod numTownCenters
    //                                                 // ToDo: fire the unit created event numTownCenters times
    //  for (var i = 0; i < numTownCenters; i++) {
    //    //UnitCreated
    //  }
    //  // ToDo: if numVillagersBuiltInThisLoop equals or exceeds upperlimit
    //  if (numVillagersBuiltInThisLoop >= upperLimit) {
    //    Serilog.Log.Debug($"The CreateVillagersLoop should stop by itself now", "Blue");
    //    StoredVAProxy.WriteToLog($"The CreateVillagersLoop should stop by itself now", "Blue");
    //  }

  })));

      }
      // Start timer
      Data.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].ResetSignal.OnNext(Unit.Default);
      // Boolean to test for loop running is the presence of the key and a non-null value not disposing or disposed
    }
    private static void Handle_StopVillagersLoop() {
      if (Data.TimerDisposeHandles.ContainsKey(StringConstants.CreateVillagersLoopTimerName)) {
        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles contains a not-null DisposeHandle for {2}", "Plugin", "Handle_StopVillagersLoop", StringConstants.CreateVillagersLoopTimerName);
        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles contains a not-null DisposeHandle for {StringConstants.CreateVillagersLoopTimerName}", "Blue");
        // TimerDisposeHandle exists, Dispose of it
        // Data.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].Dispose();
        // Remove the Key:ValueTuple from the Dictionary, implicitly will dispose of the Rx Timer
        Data.TimerDisposeHandles.Remove(StringConstants.CreateVillagersLoopTimerName);

      }
      else {
        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles does not contain a not-null DisposeHandle for {2}", "Plugin", "Handle_StopVillagersLoop", StringConstants.CreateVillagersLoopTimerName);
        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles does not contain a not-null DisposeHandle for {StringConstants.CreateVillagersLoopTimerName}", "Blue");
      }

      // set upperLimit and numTownCenters


      // Start timer, villager build time in seconds, handle increment NumVillagers
      // increment
    }
    #region Configuration sections
    public static new(List<object>, List<(string, string)>, List<string>) GetConfigurationSections() {
      Serilog.Log.Debug("{0} {1}: GetConfigurationSections Enter at {2}", "PluginVAGameAOE", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      (List<object> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = ATAP.Utilities.VoiceAttack.Game.Plugin.GetConfigurationSections();
      List<object> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.AddRange(lDCs);
      // Use the version of merge that throws an error if a duplicate key exists
      SettingsFiles.AddRange(lSFTs);
      CustomEnvironmentVariablePrefixs.AddRange(lEVPs);
      DefaultConfigurations.Add(typeof(ATAP.Utilities.VoiceAttack.Game.AOE.DefaultConfiguration));
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));
      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

    #region Populate the Data Property
    public static void InitializeData(IData newData) {
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVAGameAOE", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // ToDo: add parameter tests
      Data = newData;
      ATAP.Utilities.VoiceAttack.Game.Plugin.InitializeData(newData);
    }
    #endregion

  }
}
