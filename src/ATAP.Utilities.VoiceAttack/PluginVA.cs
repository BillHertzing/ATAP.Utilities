// cd 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.VoiceAttack'
// $src = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.VoiceAttack\bin\Debug\net4.8\*.dll'
// $target = 'C:\Program Files\VoiceAttack\Apps\ATAP.Utilities.VoiceAttack'

//dotnet build publish ATAP.Utilities.VoiceAttack.csproj /p:Configuration=Release Debug /p:DeployOnBuild=true /p:PublishProfile="properties/publishProfiles/Development.pubxml" /p:VisualStudioVersion=12.0 /p:TargetFramework=net4.8 /bl:../../_devlogs/msbuild.binlog

using System;
using System.Collections.Generic;
using System.IO;
using System.Diagnostics;
using System.Reflection;

using Serilog;

using Microsoft.Extensions.Configuration;
//using Microsoft.Extensions.Logging;
//using Microsoft.Extensions.Logging.Abstractions;

using System.Reactive;

using CollectionExtensions = ATAP.Utilities.Collection.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;

using ATAP.Utilities.HostedServices;

using ATAP.Utilities.MessageQueue;

using System.Text;

namespace ATAP.Utilities.VoiceAttack {


  public abstract class Plugin {

    public static ATAP.Utilities.VoiceAttack.IData Data { get; set; }
    public static string VA_DisplayName() {
      return "ATAP Utilities Plugin for VA\r\n"; // this is displayed in dropdowns as well as in the log file to indicate the name of the plugin
    }

    public static string VA_DisplayInfo() {
      return "ATAP Utilities Plugin\r\n\r\n"; // extended info shown tbd.  Must be formatted TBD
    }

    public static Guid VA_Id() {
      return
        new Guid("{FB2917AC-BDCB-4012-9130-E2EDA9CA7899}"); // This Guid matches the Project Guid in the Solution File
    }

    static Boolean _stopVariableToMonitor = false;

    // this function is called from VoiceAttack when the 'stop all commands' button is pressed or a, 'stop all commands' action is called.
    public static void VA_StopCommand() {
      _stopVariableToMonitor = true;
    }

    // the plugin interface has only a single dynamic parameter.
    public static void VA_Init1(dynamic vaProxy) {
      Serilog.Log.Debug("{0} {1}: VA_Init1 received at {2}", "PluginVA", "VA_Init1", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));

      // The list of environment prefixes this program wants to use
      string[] envPrefixes = new string[1] { StringConstantsVA.CustomEnvironmentVariablePrefix };

    }

    public static void VA_Exit1(dynamic vaProxy) {
      //this function gets called when VoiceAttack is closing (normally).
      // Dispose of the Data structure and all it contains
      Data.Dispose();
    }

    public static void VA_Invoke1(dynamic vaProxy) {

      string iVal = vaProxy.Context;

      Serilog.Log.Debug("{0} {1}: {2} command received at {3}", "PluginVA", "VA_Init1", iVal, DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      Data.StoredVAProxy.WriteToLog($"{iVal} command received by PluginVA at {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");

      switch (iVal) {
        case StringConstantsVA.Debug:
          Handle_Debug();
          break;


        default:  //the catch-all for for the bottom of the plugin stack, is to write a log entry that the command is unrecognized
          Serilog.Log.Debug("{0} {1}: ATAP.Utilities.VoiceAttack Plugin Error: \"{2}\" is not a known command", "PluginVA", "VA_Invoke1", iVal);
          Data.StoredVAProxy.WriteToLog("ATAP.Utilities.VoiceAttack Plugin Error: \"" + iVal + "\" is not a known command", "red");
          break;
      }

      short?
        testShort = vaProxy.GetSmallInt(
          "someValueIWantToClear"); //note that we are using short? (nullable short) in case the value is null
      if (testShort.HasValue) {
        vaProxy.SetSmallInt("someValueIWantToClear",
          null); //setting the value to null tells VoiceAttack that you want the variable removed
      }

      //here we check the context to see if we should perform an action (with some additional examples of what can be done with vaProxy
      if (vaProxy.Context == "fire weapons") {
        if (vaProxy.CommandExists("secret weapon")) //check if a command exists
        {
          if (vaProxy.ParseTokens("{ACTIVEWINDOWTITLE}") ==
              "My Awesome Game") //check the active window title using the parsetokens function
          {
            vaProxy.ExecuteCommand(
              "secret weapon"); //this tells VoiceAttack to execute the, 'secret weapon' command by name (if the command exists
          }
          else {
            vaProxy.WriteToLog("Your game was not active and on top.", "purple");
          }
        }
        else {
          vaProxy.WriteToLog("the secret weapon command does not exist.  you deleted it, didn't you?", "orange");
        }
      }

      #region Leftovers

      //here we are adding some stuff to state
      object objValue = null;
      String strStateValue = null;
      if (vaProxy.SessionState.TryGetValue("myStateValue",
        out objValue)) //we check to see if there is a value in state for 'myStateValue'
      {
        strStateValue =
          (String)objValue; //if we find something, we are going to cast it as a string and use it somewhere in here...
      }
      else
        strStateValue =
          "initialized"; //nothing was found in state... just set the string to, 'initialized' and keep moving...

      //hope that helps some!
      #endregion
    }

    public static void Handle_Debug() {
      Data.StoredVAProxy.Command.Execute("Say Debug");
    }

    #region Configuration sections
    public static (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      // ToDo: add commandline arguments.
      Serilog.Log.Debug("{0} {1}: GetConfigurationSections Enter at {2}", "PluginVA", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.Add(ATAP.Utilities.VoiceAttack.DefaultConfigurationVA.Production);
      SettingsFiles.Add((StringConstantsGenericHost.GenericHostSettingsFileName, StringConstantsGenericHost.GenericHostSettingsFileNameSuffix));
      SettingsFiles.Add((StringConstantsVA.SettingsFileName, StringConstantsVA.SettingsFileNameSuffix));
      CustomEnvironmentVariablePrefixs.Add(StringConstantsVA.CustomEnvironmentVariablePrefix);
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

    #region Populate the Data Property
    public static void SetData(IData newData) {
      Serilog.Log.Debug("{0} {1}: SetData Enter at {2}", "PluginVA", "SetData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      Data = (Data)newData;
    }
    #endregion


    #region Initialize the Data's Autoproperties
    public static void InitializeData() {
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVA", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // Configure the audio output.
      Data.SpeechSynthesizer.SetOutputToDefaultAudioDevice();
    }
    #endregion

    #region Setup the loggers
    public static void InitializeLogger() {
      // Configure a startup Logger, prior to getting the Logger configuration from the ConfigurationRoot
      #region Startup logger
      // Serilog is the logging provider I picked to provide a logging solution for the VoiceAttack ATAP Plugin
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined Sources
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      Serilog.Debugging.SelfLog.Enable(System.Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      Serilog.Debugging.SelfLog.Enable(msg => Debug.WriteLine(msg));
      Serilog.Debugging.SelfLog.WriteLine("in InitializeLogger(Serilog Self Log)");
      // Another example is at https://github.com/serilog/serilog-extensions-logging/blob/dev/samples/Sample/Program.cs
      // Another is https://nblumhardt.com/2019/10/serilog-in-aspnetcore-3/
      // Creating a `LoggerProviderCollection` lets Serilog optionally write events through other dynamically-added MEL ILoggerProviders.
      // var providers = new LoggerProviderCollection();

      // Setup Serilog's static Logger with an initial configuration sufficient to log startup errors
      // create a local Serilog Logger for use during Program startup
      var serilogLoggerConfiguration = new Serilog.LoggerConfiguration()
        .MinimumLevel.Verbose()
        .Enrich.FromLogContext()
        //.Enrich.WithExceptionDetails()
        .Enrich.WithThreadId()
        // .WriteTo.Console(outputTemplate: "Static startup Serilog {Timestamp:HH:mm:ss zzz} [{Level}] ({Name:l}) {Message}{NewLine}{Exception}")
        .WriteTo.Seq(serverUrl: "http://localhost:5341")
        .WriteTo.File(
          path:
          @"C:\\Dropbox\\whertzing\\GitHub\\ATAP.Utilities\\_devlogs\\ATAP.Utilities.VoiceAttack.{Timestamp:yyyy-MM-dd HH:mm:ss}.log",
          fileSizeLimitBytes: 1024,
          outputTemplate:
          "Static startup Serilog {Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level}] {Message}{NewLine}{Exception}",
          rollingInterval: RollingInterval.Day, rollOnFileSizeLimit: true, retainedFileCountLimit: 31)
        .WriteTo.Debug();
      //.Enrich.WithHttpRequestId()
      //.Enrich.WithUserName()
      //.WriteTo.Providers(providers)

      Serilog.Core.Logger serilogLogger = serilogLoggerConfiguration.CreateLogger();
      // Set the Static Logger called Log to use this LoggerConfiguration
      Serilog.Log.Logger = serilogLogger;
      Serilog.Log.Debug("{0} {1}: The Serilog startup logger is defined with a default startup configuration", "PluginVA", "InitializeLogger");
      // Temp for testing the build configurations and the Trace #define
#if TRACE
      Serilog.Log.Debug("TRACE is defined");
#else
      Serilog.Log.Debug("TRACE is NOT defined");
#endif
      // end temp

      // MEL Logging causes problem with Logging.Abstractions assembly versions, neither net.5 V5.0.0 nor Net Desktop 4.8 3.16 version
      // Set the MEL LoggerFactory to use this LoggerConfiguration
      // Microsoft.Extensions.Logging.ILoggerFactory mELoggerFactory = new Microsoft.Extensions.Logging.LoggerFactory().AddSerilog();
      // Microsoft.Extensions.Logging.ILogger mELlogger = mELoggerFactory.CreateLogger("Program");
      #endregion
    }

    #endregion
    #region Create message queues for the Plugin base abstract class
    public static void CreateMessageQueues() {

      //CreateConnection();
    }
    #endregion

    #region Attach Event Handlers specific to GameAOE
    public static void AttachEventHandlers() { }

    public static void ProfileChangingAction(Guid? FromInternalID, Guid? ToInternalID,
     String FromName, String ToName) {
      Serilog.Log.Debug("{0} {1}: Profile Changing Event Handler, Profile changing from {2}, ID: {3} to {4}, ID: {5}", "PluginVA", "ProfileChangingAction", FromName, FromInternalID.ToString(), ToName, ToInternalID.ToString());
    }
    public static void ProfileChangedAction(Guid? FromInternalID, Guid? ToInternalID,
     String FromName, String ToName) {
      Serilog.Log.Debug("{0} {1}: Profile Changing Event Handler, Profile changed from {2}, ID: {3} to {4}, ID: {5}", "PluginVA", "ProfileChangedAction", FromName, FromInternalID.ToString(), ToName, ToInternalID.ToString());
    }
    public static void ApplicationFocusChangedAction(System.Diagnostics.Process Process, String TopmostWindowTitle) {
      Serilog.Log.Debug("{0} {1}: ApplicationFocus Changed Event Handler, Application focus changed to {2}", "PluginVA", "ApplicationFocusChangedAction", TopmostWindowTitle);
    }

    #endregion
  }
}

