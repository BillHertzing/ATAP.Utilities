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

using StringConstantsVAGameAOE = ATAP.Utilities.VoiceAttack.Game.AOE.StringConstants;
using StringConstantsVAGame = ATAP.Utilities.VoiceAttack.Game.StringConstants;
using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;
using StringConstantsGenericHost = ATAP.Utilities.VoiceAttack.StringConstantsGenericHost;

using ATAP.Utilities.MessageQueue;
// Used to Serialize objects for the MessageQueue
using ATAP.Utilities.Serializer;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.VoiceAttack.Game.AOE {

  public abstract class Plugin : ATAP.Utilities.VoiceAttack.Game.Plugin {

    public new static ATAP.Utilities.VoiceAttack.Game.AOE.IData Data { get; set; }

    public new static string VA_DisplayName() {
      var str = "ATAP Utilities Plugin for VAGamesAOE\r\n" + ATAP.Utilities.VoiceAttack.Game.Plugin.VA_DisplayName();
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
      Data.StoredVAProxy.WriteToLog($"{iVal} command received by PluginVAGameAOE at {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");

      switch (iVal) {
        case StringConstantsVAGame.Context_StartGame:
          Handle_StartGame();
          break;

        case StringConstants.Context_CreateVillagersLoop_Default:
          int upperLimit = 26; // ToDo set int in command, read int from proxy
          int numStructures = 1; // ToDo set int in command, read int from proxy
          Handle_CreateVillagersLoop(upperLimit, numStructures);
          break;
        case StringConstants.Context_CreateFishingBoatsLoop_Default:
          Data.StoredVAProxy.WriteToLog($"Create CreateFishingBoatsLoop Loops started {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");
          break;
        default:  //the catch-all for an unrecognized Context is send it down one layer in the plugin stack
          ATAP.Utilities.VoiceAttack.Game.Plugin.VA_Invoke1((object)vaProxy);
          break;
      }
    }


    public new static void Handle_StartGame() {
      // Start with letting the Game level plugin do its thing
      ATAP.Utilities.VoiceAttack.Game.Plugin.Handle_StartGame();
      int VillagerBuildTimeInSeconds = 20;
      short InitialNumberOfVillagers = 3;
      int InterCommandPauseInMilliseconds = 500;

      // Now build a list of Actions to perform for AOE
      var StartVoiceAttackActionList = new List<VoiceAttackActionWithDelay>(){
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionCommand(StringConstants.Command_Create_Villagers_In_One_Limit_22), new TimeSpan(0,0,0,InterCommandPauseInMilliseconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_First_Six_Villagers_on_Sheep), new TimeSpan(0,0,((6-InitialNumberOfVillagers)*VillagerBuildTimeInSeconds))),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Four_Villagers_on_Wood), new TimeSpan(0,0,(4*VillagerBuildTimeInSeconds))),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Villager_Lure_Boar), new TimeSpan(0,0,VillagerBuildTimeInSeconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_To_Berries_Build_House_Build_Mill), new TimeSpan(0,0,VillagerBuildTimeInSeconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Two_Villagers_To_Berries), new TimeSpan(0,0,(2*VillagerBuildTimeInSeconds))),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Wood_Villager_Build_House), new TimeSpan(0,0,0,InterCommandPauseInMilliseconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Villager_Lure_Boar), new TimeSpan(0,0,VillagerBuildTimeInSeconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Two_Villagers_To_Boar), new TimeSpan(0,0,(2*VillagerBuildTimeInSeconds))),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Three_Villagers_To_Wood), new TimeSpan(0,0,(3*VillagerBuildTimeInSeconds))),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay(StringConstants.Say_Next_Villager_To_Sheep), new TimeSpan(0,0,VillagerBuildTimeInSeconds)),
        new VoiceAttackActionWithDelay(new TimeSpan(0,0,0,InterCommandPauseInMilliseconds), (IVoiceAttackActionAbstract)new VoiceAttackActionSay("On Your own now!"), new TimeSpan(0,0,0,InterCommandPauseInMilliseconds))
      };
      foreach (var a in StartVoiceAttackActionList) {
        // Debugging, uncomment to see the list of actions prior to sending to the message queue
        switch (a.VoiceAttackAction.VoiceAttackActionKind) {
          case VoiceAttackActionKind.Say:
            Serilog.Log.Debug("{0} {1}: VoiceAttackAction Say {2}", "PluginVAGameAOE", "Handle_StartGame", ((VoiceAttackActionSay)a.VoiceAttackAction).Phrase);
            break;
          case VoiceAttackActionKind.Command:
            Serilog.Log.Debug("{0} {1}: VoiceAttackAction Command {2}", "PluginVAGameAOE", "Handle_StartGame", ((VoiceAttackActionCommand)a.VoiceAttackAction).Command);
            break;
          case VoiceAttackActionKind.Delay:
            break;
          default:
            throw new InvalidDataException($"Invalid VoiceAttackActionKind {a.VoiceAttackAction.VoiceAttackActionKind}");
        }
      }
      // End debugging block
      foreach (var vaa in StartVoiceAttackActionList) {
        // For a DI Injected service,cast to the concrete implementation from the service factory???
        // Cast the IAbstract to the concrete implementation
        // ((ATAP.Utilities.MessageQueue.Shim.RabbitMQT.RabbitMQMessageQueue<SendMessageResults>)Data.MessageQueue).SendMessage(((ATAP.Utilities.VoiceAttack.Game.AOE.Data)Data).ToByteArray(vaa));
        ((ATAP.Utilities.MessageQueue.Shim.TPL.TPLMessageQueue<SendMessageResults>)Data.MessageQueue).SendMessage(((ATAP.Utilities.VoiceAttack.Game.AOE.Data)Data).ToByteArray(vaa));
      }
    }


    private static void Handle_CreateVillagersLoop(int upperLimit, int numTownCenters) {

      if (Data.ObservableResetableTimersHostedServiceData.TimerDisposeHandles.ContainsKey(StringConstants.CreateVillagersLoopTimerName)) {
        // Timer already exists, write to log

        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles already contains a not-null DisposeHandle for {2}", "Plugin", "Handle_CreateVillagersLoop", StringConstants.CreateVillagersLoopTimerName);

        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles already contains a not-null DisposeHandle for {StringConstants.CreateVillagersLoopTimerName}", "Blue");

        // ToDo: set upperLimit and numTownCenters somewhere
        //Data.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].Timer.Enabled = true;
      }
      else {
        // Duration is from Data configuration
        var durationAsString = Data.CurrentVillagerBuildTimeSpan;
        Data.ObservableResetableTimersHostedServiceData.AddTimer(StringConstants.CreateVillagersLoopTimerName, true, Data.CurrentVillagerBuildTimeSpan, new Action(() => {
          // Handle the timer event in this lambda Action. This lambda closes over a local variable set to the value of numTownCenters, and another which counts the number of villagers created in this loop, and the upperLimiit parameter
          // This lambda writes to the dynamic StoredVAProxy Command
          // This lambda calls another command to stop the loop when the upperlimit of villagers has been built

          // Serilog.Log.Debug("{0} {1}: The CreateVillagersLoopObservableResetableTimer fired at {2}", "Plugin", "OnCreateVillagersLoopObservableResetableTimerEvent", e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT));
          // StoredVAProxy.WriteToLog($"The CreateVillagersLoopObservableResetableTimer fired at {e.SignalTime.ToString(StringConstantsVA.DATE_FORMAT)}", "Blue");
          Serilog.Log.Debug("{0} {1}: The {2}} fired", "Plugin", "CreateVillagersLoopTimer", StringConstants.CreateVillagersLoopTimerName);
          Data.StoredVAProxy.WriteToLog($"The {StringConstants.CreateVillagersLoopTimerName} fired", "Purple");
          //  numVillagersBuiltInThisLoop += numTownCenters; // ToDo: account for non zero upperlimit mod numTownCenters
          //                                                 // ToDo: fire the unit created event numTownCenters times
          //  for (var i = 0; i < numTownCenters; i++) {
          //    //UnitCreated
          //  }
          //  // ToDo: if numVillagersBuiltInThisLoop equals or exceeds upperlimit
          //  if (numVillagersBuiltInThisLoop >= upperLimit) {
          //    Serilog.Log.Debug($"The CreateVillagersLoop should stop by itself now", "Blue");
          //    Data.StoredVAProxy.WriteToLog($"The CreateVillagersLoop should stop by itself now", "Blue");
          //  }

        }));

      }
      // Start timer
      Data.ObservableResetableTimersHostedServiceData.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].ResetSignal.OnNext(Unit.Default);
      // Boolean to test for loop running is the presence of the key and a non-null value not disposing or disposed
    }
    private static void Handle_StopVillagersLoop() {
      if (Data.ObservableResetableTimersHostedServiceData.TimerDisposeHandles.ContainsKey(StringConstants.CreateVillagersLoopTimerName)) {
        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles contains a not-null DisposeHandle for {2}", "Plugin", "Handle_StopVillagersLoop", StringConstants.CreateVillagersLoopTimerName);
        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles contains a not-null DisposeHandle for {StringConstants.CreateVillagersLoopTimerName}", "Blue");
        // TimerDisposeHandle exists, Dispose of it
        // Data.TimerDisposeHandles[StringConstants.CreateVillagersLoopTimerName].Dispose();
        // Remove the Key:ValueTuple from the Dictionary, implicitly will dispose of the Rx Timer
        Data.ObservableResetableTimersHostedServiceData.TimerDisposeHandles.Remove(StringConstants.CreateVillagersLoopTimerName);

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
    public static new (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      Serilog.Log.Debug("{0} {1}: GetConfigurationSections Enter at {2}", "PluginVAGameAOE", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = ATAP.Utilities.VoiceAttack.Game.Plugin.GetConfigurationSections();
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.AddRange(lDCs);
      // Use the version of merge that throws an error if a duplicate key exists
      SettingsFiles.AddRange(lSFTs);
      CustomEnvironmentVariablePrefixs.AddRange(lEVPs);
      DefaultConfigurations.Add(ATAP.Utilities.VoiceAttack.Game.AOE.DefaultConfiguration.Production);
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));
      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

    #region Populate the Data Property
    public static void SetData(IData newData) {
      Serilog.Log.Debug("{0} {1}: SetData Enter at {2}", "PluginVAGameAOE", "SetData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      Data = (Data)newData;
      ATAP.Utilities.VoiceAttack.Game.Plugin.SetData(newData);
    }
    #endregion

    #region Initialize the Data's Autoproperties
    public new static void InitializeData() {
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVAGameAOE", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // ToDo: add parameter tests
      // Any data that is taken from Configuration sections must be vetted.
      #region Local Variables used inside .ctor
      TimeSpan ts;
      string durationAsString;
      short n;
      string shortAsString;
      #endregion
      #region Initialize data for the CreateVillagers Action
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVAGameAOE", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // Initial value of CurrentVillagerBuildTimeSpan duration is from configuration
      durationAsString = Data.ConfigurationRoot.GetValue<string>(StringConstantsVAGameAOE.VillagerBuildTimeSpanConfigRootKey, StringConstantsVAGameAOE.VillagerBuildTimeSpanDefault);
      try {
        ts = TimeSpan.Parse(durationAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and cannot be parsed as a TimeSpan", "ATAPPluginGameAOE", "Data(.ctor)", durationAsString);
        Data.StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and cannot be parsed as a TimeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: durationAsString is {2} and is outside the range of a TimeSpan", "ATAPPluginGameAOE", "Data(.ctor)", durationAsString);
        Data.StoredVAProxy.WriteToLog($"durationAsString is {durationAsString} and is outside the range of a TimeSpan", "Red");
        throw new InvalidDataException($"durationAsString is {durationAsString} and is outside the range of a TimeSpan");
      }

      Data.CurrentVillagerBuildTimeSpan = ts;

      shortAsString = Data.ConfigurationRoot.GetValue<string>(StringConstantsVAGameAOE.InitialNumVillagersConfigRootKey, StringConstantsVAGameAOE.InitialNumVillagersDefault);
      try {
        n = short.Parse(shortAsString);
      }
      catch (FormatException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and cannot be parsed as a short", "ATAPPluginGameAOE", "Data(.ctor)", shortAsString);
        Data.StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and cannot be parsed as a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and cannot be parsed as a TishortmeSpan");
      }
      catch (OverflowException) {
        Serilog.Log.Debug("{0} {1}: shortAsString is {2} and is outside the range of a short", "ATAPPluginGameAOE", "Data(.ctor)", shortAsString);
        Data.StoredVAProxy.WriteToLog($"shortAsString is {shortAsString} and is outside the range of a short", "Red");
        throw new InvalidDataException($"shortAsString is {shortAsString} and is outside the range of a short");
      }
      Data.CurrentNumVillagers = n;
      #endregion

      #region Initialize Structures, Units, Technologies
      Data.Structures = new();
      //Data.Units = new();
      //Data.Technologies = new();

      Data.Structures.Add(new TownCenter());
      #endregion

      #region Initial Build Order
      //Data.StoredVAProxy.
      #endregion

      ATAP.Utilities.VoiceAttack.Game.Plugin.InitializeData();
    }
    #endregion

    #region Create message queues unique to AOE
    public static Action<byte[]> ReceiveActionHelper() {
      return new Action<byte[]>((message) => {
        Serilog.Log.Debug("{0} {1}: Message Received Handler, Message is {2}", "PluginVAGameAOE", "ReceiveMessage", System.Text.Encoding.UTF8.GetString(message, 0, message.Length));
        // Convert byte[] to an Game AOE message
        VoiceAttackActionWithDelay voiceAttackActionWithDelay = ((ATAP.Utilities.VoiceAttack.Game.AOE.Data)Data).FromByteArray(message);
        switch (voiceAttackActionWithDelay.VoiceAttackAction.VoiceAttackActionKind) {
          case VoiceAttackActionKind.Say:
            Serilog.Log.Debug("{0} {1}: VoiceAttackAction Say {2}", "PluginVAGameAOE", "ReceiveMessage", ((VoiceAttackActionSay)voiceAttackActionWithDelay.VoiceAttackAction).Phrase);
            // toDo: PreDelay
            Data.SpeechSynthesizer.Speak(((VoiceAttackActionSay)voiceAttackActionWithDelay.VoiceAttackAction).Phrase);
            // toDo: PostDelay
            break;
          case VoiceAttackActionKind.Command:
            Serilog.Log.Debug("{0} {1}: VoiceAttackAction Command {2}", "PluginVAGameAOE", "ReceiveMessage", ((VoiceAttackActionCommand)voiceAttackActionWithDelay.VoiceAttackAction).Command);
            // toDo: PreDelay
            Data.StoredVAProxy.Command.Execute(((VoiceAttackActionCommand)voiceAttackActionWithDelay.VoiceAttackAction).Command);
            // toDo: PostDelay
            break;
          case VoiceAttackActionKind.Delay:
            break;
          // ToDo: Delay command
          default:
            throw new InvalidDataException($"Invalid VoiceAttackActionKind {voiceAttackActionWithDelay.VoiceAttackAction.VoiceAttackActionKind.ToString()}");
        };
      });
    }
    public new static void CreateMessageQueues() {
      ATAP.Utilities.VoiceAttack.Game.Plugin.CreateMessageQueues();
      // In a DI Injected context, a MessageQueue object for this game would be requested from a Service
      // This VA PLugin implementation requires .Net 4.7.2+, and directly calls the MessageQueue Shim.
      // For the TPL Shim

      Data.MessageQueue = new ATAP.Utilities.MessageQueue.Shim.TPL.TPLMessageQueue<SendMessageResults>(
      // Action to be taken when a message is received
      receiveAction: ReceiveActionHelper()
      );
      // For the RabbitMQ Shim
      // Data.MessageQueue = new ATAP.Utilities.MessageQueue.Shim.RabbitMQT.RabbitMQMessageQueue<SendMessageResults>(
      // // Server Information, In a DI context from ConfigurationRoot, From StringConstants when using the Shim directly, or just take defaults from Shim
      // // Shim defaults correspond to the RabbitMQ tutorial values
      // // ToDo: get from string constants
      // rabbitMQMessageServerOptions: null,
      // // Queue Information, In a DI context from ConfigurationRoot, From StringConstants when using the Shim directly
      // // Shim defaults correspond to the RabbitMQ tutorial values
      // // ToDo: get from string constants
      // rabbitMQMessageQueueOptions: null,
      // // Action to be taken when a message is received
      // receiveAction: ReceiveActionHelper()
      // );
    }
    #endregion

    #region Create Serializer for the Messages specific to GameAOE
    public static void CreateSerializer() {
      var jsonSerializerOptions = new JsonSerializerOptions() {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull, // Handle nullable properties in an object
        WriteIndented = true,
      };
      // Add converter for the VoiceAttackAction type
      //jsonSerializerOptions.Converters.Add();
      // A serializer with the jsonSerializerOptions defined above
      Data.Serializer = new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer(jsonSerializerOptions);
      // A serializer with just defaults.
      //Data.Serializer = new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer();
    }
    #endregion

    #region Attach Event Handlers specific to GameAOE
    public new static void AttachEventHandlers() {
      Data.StoredVAProxy.ProfileChanging += new Action<Guid?, Guid?, String, String>(ProfileChangingAction);
      Data.StoredVAProxy.ProfileChanged += new Action<Guid?, Guid?, String, String>(ProfileChangedAction);
      Data.StoredVAProxy.ApplicationFocusChanged += new Action<System.Diagnostics.Process, String>(ApplicationFocusChangedAction);
      ATAP.Utilities.VoiceAttack.Game.Plugin.AttachEventHandlers();

    }
    public new static void ProfileChangingAction(Guid? FromInternalID, Guid? ToInternalID, String FromName, String ToName) {
      Serilog.Log.Debug("{0} {1}: Profile Changing Event Handler, Profile changing from {2}, ID: {3} to {4}, ID: {5}", "PluginVAGameAOE", "ProfileChangingAction", FromName, FromInternalID.ToString(), ToName, ToInternalID.ToString());
      ATAP.Utilities.VoiceAttack.Game.Plugin.ProfileChangingAction(FromInternalID, ToInternalID, FromName, ToName);

    }
    public new static void ProfileChangedAction(Guid? FromInternalID, Guid? ToInternalID, String FromName, String ToName) {
      Serilog.Log.Debug("{0} {1}: Profile Changing Event Handler, Profile changed from {2}, ID: {3} to {4}, ID: {5}", "PluginVAGameAOE", "ProfileChangedAction", FromName, FromInternalID.ToString(), ToName, ToInternalID.ToString());
      ATAP.Utilities.VoiceAttack.Game.Plugin.ProfileChangedAction(FromInternalID, ToInternalID, FromName, ToName);
    }

    public new static void ApplicationFocusChangedAction(System.Diagnostics.Process Process, String TopmostWindowTitle) {
      Serilog.Log.Debug("{0} {1}: ApplicationFocus Changed Event Handler, Application focus changed to {2}", "PluginVAGameAOE", "ApplicationFocusChangedAction", TopmostWindowTitle);
      ATAP.Utilities.VoiceAttack.Game.Plugin.ApplicationFocusChangedAction(Process, TopmostWindowTitle);
    }
    #endregion

  }
}
