// cd 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.VoiceAttack'
// $src = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.VoiceAttack\bin\Debug\net4.8\*.dll'
// $target = 'C:\Program Files\VoiceAttack\Apps\ATAP.Utilities.VoiceAttack'

//dotnet build publish ATAP.Utilities.VoiceAttack.csproj /p:Configuration=Release Debug /p:DeployOnBuild=true /p:PublishProfile="properties/publishProfiles/Development.pubxml" /p:VisualStudioVersion=12.0 /p:TargetFramework=net4.8 /bl:../../_devlogs/msbuild.binlog

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

using GenericHostExtensions = ATAP.Utilities.GenericHost.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;

using ATAP.Utilities.HostedServices;

using AOEStringConstants = ATAP.Utilities.VoiceAttack.AOE.StringConstants;

namespace ATAP.Utilities.VoiceAttack {


  public class ATAPUtilitiesVoiceAttackPluginData {
    public List<Structure> Structures { get; set; }

    public ATAPUtilitiesVoiceAttackPluginData() {
      Structures = new List<Structure>();
      Structures.Add(new TownCenter());

    }
  }

  public partial class ATAPUtilitiesVoiceAttackPlugin {

    public static Data Data { get; set; }
    public static string VA_DisplayName() {
      return
        "ATAP Utilities Plugin for Age Of Empires V0.1.0-alpha"; // this is displayed in dropdowns as well as in the log file to indicate the name of the plugin
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
      #region Startup logger

      // Configure a startup Logger, prior to getting the Logger configuration from the ConfigurationRoot
      // Serilog is the logging provider I picked to provide a logging solution for the VoiceAttack ATAP Plugin
      // Enable Serilog's internal debug logging. Note that internal logging will not write to any user-defined Sources
      //  https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs
      Serilog.Debugging.SelfLog.Enable(System.Console.Out);
      // Another example is at https://stackify.com/serilog-tutorial-net-logging/
      //  This brings in the System.Diagnostics.Debug namespace and writes the SelfLog there
      Serilog.Debugging.SelfLog.Enable(msg => Debug.WriteLine(msg));
      Serilog.Debugging.SelfLog.WriteLine("in Program.Main(Serilog Self Log)");
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
          @"C:\Dropbox\whertzing\GitHub\ATAP.Utilities\_devlogs\ATAP.Utilities.VoiceAttack.{Timestamp:yyyy-MM-dd HH:mm:ss}.log",
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
      Serilog.Log.Debug("{0} {1}: The VoiceAttack Plugin ATAP.Utilities.VoiceAttack is starting", "ATAPPlugin", "VA_Init1");
      Serilog.Log.Debug("{0} {1}: LoggerFactory and local Logger defined with a default startup configuration:",
        "ATAPPlugin", "VA_Init1");

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
      // Serilog.Log.Debug("{0} {1}: The program Console02 is starting", "Program", "Main");
      // Serilog.Log.Debug("{0} {1}: LoggerFactory and local Logger defined with a default startup configuration:", "Program", "Main");
      #endregion

      #region initialStartup and loadedFrom directories
      // When running as a Windows service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a *nix service, the initial working dir could be anything. The program (and machine-wide configuration files) are probably installed in the location where the service starts. //ToDo: verify this
      // When running as a Windows or Linux Console App, the initial working dir could be anything, but the program (and machine-wide configuration files) is probably installed to a different directory.
      // When running as a console app, it is very possible that there may be local (to the initial startup directory) configuration files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      var initialStartupDirectory = Directory.GetCurrentDirectory(); //ToDo: Catch exceptions
      Serilog.Log.Debug("{0} {1}: initialStartupDirectory: {2}", "ATAPPlugin", "VA_Init1", initialStartupDirectory);
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); //ToDo: Catch exceptions
      Serilog.Log.Debug("{0} {1}: loadedFromDirectory: {2}", "ATAPPlugin", "VA_Init1", loadedFromDirectory);
      #endregion region

      // The list of environment prefixes this program wants to use
      string[] envPrefixes = new string[1] { StringConstants.EnvironmentVariablePrefixConfigRootKey };

      #region initial ConfigurationBuilder and ConfigurationRoot
      // Create the initial ConfigurationBuilder for this 's ConfigurationRoot. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      // Initial configuration does not take Environment into account.
      var configurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(
        DefaultConfiguration.Production, true, null, StringConstants.SettingsFileName,
        StringConstants.SettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, envPrefixes, null, null);

      // Create this program's initial ConfigurationRoot
      var configurationRoot = configurationBuilder.Build();
      #endregion

      #region (optional) Debugging the Configuration
      // for debugging and education, uncomment this region and inspect the two section Lists (using debugger Locals) to see exactly what is in the configuration
      //    var sections = configurationRoot.GetChildren();
      //    List<IConfigurationSection> sectionsAsListOfIConfigurationSections = new List<IConfigurationSection>();
      //    List<ConfigurationSection> sectionsAsListOfConfigurationSections = new List<ConfigurationSection>();
      //    foreach (var iSection in sections) sectionsAsListOfIConfigurationSections.Add(iSection);
      //    foreach (var iSection in sectionsAsListOfIConfigurationSections) sectionsAsListOfConfigurationSections.Add((ConfigurationSection)iSection);
      #endregion

      #region Environment determination and validation
      // ToDo: Before the genericHost is built, have to use a StringConstant for the string that means "Production", and hope the ConfigurationRoot value for Environment matches the StringConstant
      // Determine the environment (Debug, TestingUnit, TestingX, QA, QA1, QA2, ..., Staging, Production) to use from the initialconfigurationRoot
      var envNameFromConfiguration = configurationRoot.GetValue<string>(GenericHostStringConstants.EnvironmentConfigRootKey, GenericHostStringConstants.EnvironmentDefault);
      Serilog.Log.Debug("{0} {1}: Initial environment name: {2}", "ATAPPlugin", "VA_Init1", envNameFromConfiguration);

      // optional: Validate that the environment provided is one this program understands how to use
      // Accepting any string for envNameFromConfiguration might pose a security risk, as it will allow arbitrary files to be loaded into the configuration root
      switch (envNameFromConfiguration) {
        case GenericHostStringConstants.EnvironmentDevelopment:
          // ToDo: Programmers can add things here
          break;
        case GenericHostStringConstants.EnvironmentProduction:
          // This is the expected leg for Production environment
          break;
        default:
          // IF you want to accept any environment name as OK, just comment out the following throw
          // Keep the throw in here if you want to explicitly disallow any environment other than ones specified in the switch
          throw new NotImplementedException($"The Environment {envNameFromConfiguration} is not supported");
      };
      #endregion

      #region final (Environment-aware) configurationBuilder and appConfigurationBuilder
      // If the initial configurationRoot specifies the Environment is production, then the configurationBuilder is correct  "as-is"
      //   but if not, build a 2nd (final) configurationBuilder, this time including environment-specific configuration providers
      if (envNameFromConfiguration != GenericHostStringConstants.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this genericHost, this time including environment-specific configuration providers.
        Serilog.Log.Debug("{0} {1}: Recreating configurationBuilder for Environment: {2}", "Program", "Main", envNameFromConfiguration);
        configurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(DefaultConfiguration.Production, false, envNameFromConfiguration,
          StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, null, null, null);
      }

      // Create the appConfigurationBuilder, either as Production or as some other environment specific
      IConfigurationBuilder appConfigurationBuilder;
      Serilog.Log.Debug("{0} {1}: Creating appConfigurationBuilder for Environment: {2}", "Program", "Main", envNameFromConfiguration);
      appConfigurationBuilder = ConfigurationExtensions.ATAPStandardConfigurationBuilder(DefaultConfiguration.Production, envNameFromConfiguration == GenericHostStringConstants.EnvironmentProduction, envNameFromConfiguration,
        StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix, loadedFromDirectory, initialStartupDirectory, envPrefixes, null, null);

      // Create the configurationRoot
      configurationRoot = appConfigurationBuilder.Build();
      #endregion

      // Instantiate the Data and store away the reference to the VAProxy
      Data = new Data(configurationRoot, vaProxy);
      Serilog.Log.Debug("{0} {1}: static Data instance created", "Program", "Main");
      Data.StoredVAProxy.WriteToLog("static Data instance created", "Blue");

      //vaProxy.SessionState.Add("new state value", 369); //set whatever private state information you want to maintain (note this is a dictionary of (string, object)
      //vaProxy.SessionState.Add("second new state value", "hello");
    }

    public static void VA_Exit1(dynamic vaProxy) {
      //this function gets called when VoiceAttack is closing (normally).
      // Dispose of the Data structure and all it contains
      Data.Dispose();
    }

    private static void Handle_CreateVillagersLoop(int upperLimit, int numTownCenters) {

      if (Data.TimerDisposeHandles.ContainsKey(AOEStringConstants.CreateVillagersLoopTimerName)) {
        // Timer already exists, write to log

        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles already contains a not-null DisposeHandle for {2}", "Plugin", "Handle_CreateVillagersLoop", AOEStringConstants.CreateVillagersLoopTimerName);

        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles already contains a not-null DisposeHandle for {AOEStringConstants.CreateVillagersLoopTimerName}", "Blue");

        // ToDo: set upperLimit and numTownCenters somewhere
        //Data.TimerDisposeHandles[AOEStringConstants.CreateVillagersLoopTimerName].Timer.Enabled = true;
      }
      else {
        // Duration is from Data configuration
        var durationAsString = Data.CurrentVillagerBuildTimeSpan;
        Data.TimerDisposeHandles.Add(AOEStringConstants.CreateVillagersLoopTimerName, new ObservableResetableTimer(Data.CurrentVillagerBuildTimeSpan,
 new Action(() => {
   // Handle the timer event in this lambda Action. This lambda closes over a local variable set to the value of numTownCenters, and another which counts the number of villagers created in this loop, and the upperLimiit parameter
   // This lambda writes to the dynamic StoredVAProxy Command
   // This lambda calls another command to stop the loop when the upperlimit of villagers has been built

   // Serilog.Log.Debug("{0} {1}: The CreateVillagersLoopObservableResetableTimer fired at {2}", "Plugin", "OnCreateVillagersLoopObservableResetableTimerEvent", e.SignalTime.ToString(StringConstants.DATE_FORMAT));
   // StoredVAProxy.Command.WriteToLog($"The CreateVillagersLoopObservableResetableTimer fired at {e.SignalTime.ToString(StringConstants.DATE_FORMAT)}", "Blue");
   Serilog.Log.Debug("{0} {1}: The {2}} fired", "Plugin", "CreateVillagersLoopTimer", AOEStringConstants.CreateVillagersLoopTimerName);
   Data.StoredVAProxy.Command.WriteToLog($"The {AOEStringConstants.CreateVillagersLoopTimerName} fired", "Purple");
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
      Data.TimerDisposeHandles[AOEStringConstants.CreateVillagersLoopTimerName].ResetSignal.OnNext(Unit.Default);
      // Boolean to test for loop running is the presence of the key and a non-null value not disposing or disposed
    }
    private static void Handle_StopVillagersLoop() {
      if (Data.TimerDisposeHandles.ContainsKey(AOEStringConstants.CreateVillagersLoopTimerName)) {
        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles contains a not-null DisposeHandle for {2}", "Plugin", "Handle_StopVillagersLoop", AOEStringConstants.CreateVillagersLoopTimerName);
        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles contains a not-null DisposeHandle for {AOEStringConstants.CreateVillagersLoopTimerName}", "Blue");
        // TimerDisposeHandle exists, Dispose of it
        // Data.TimerDisposeHandles[AOEStringConstants.CreateVillagersLoopTimerName].Dispose();
        // Remove the Key:ValueTuple from the Dictionary, implicitly will dispose of the Rx Timer
        Data.TimerDisposeHandles.Remove(AOEStringConstants.CreateVillagersLoopTimerName);

      }
      else {
        Serilog.Log.Debug("{0} {1}: Data.TimerDisposeHandles does not contain a not-null DisposeHandle for {2}", "Plugin", "Handle_StopVillagersLoop", AOEStringConstants.CreateVillagersLoopTimerName);
        Data.StoredVAProxy.WriteToLog($"Data.TimerDisposeHandles does not contain a not-null DisposeHandle for {AOEStringConstants.CreateVillagersLoopTimerName}", "Blue");
      }

      // set upperLimit and numTownCenters


      // Start timer, villager build time in seconds, handle increment NumVillagers
      // increment
    }
    public static void VA_Invoke1(dynamic vaProxy) {

      string iVal = vaProxy.Context;

      Serilog.Log.Debug("{0} {1}: {2} command received at {3}", "Plugin", "VA_Init1", iVal, DateTime.Now.ToString(StringConstants.DATE_FORMAT));
      vaProxy.WriteToLog($"{iVal} command received at {DateTime.Now.Ticks.ToString()}", "blue");

      switch (iVal) {
        case Data.ConfigurationRoot.GetValue<string>(AOEStringConstants.Context_CreateVillagersLoop_ConfigRootKey, AOEStringConstants.Context_CreateVillagersLoop_Default):
          int upperLimit = 26; // ToDo set int in command, read int from proxy
          int numStructures = 1; // ToDo set int in command, read int from proxy
          Handle_CreateVillagersLoop(upperLimit, numStructures);
          break;
        case Data.ConfigurationRoot.GetValue<string>(AOEStringConstants.Context_CreateFishingBoatsLoop_ConfigRootKey, AOEStringConstants.Context_CreateFishingBoatsLoop_Default):
          // case "CreateFishingBoatsLoop":
          vaProxy.WriteToLog($"Create CreateFishingBoatsLoop Loops started {DateTime.Now.Ticks.ToString()}", "blue");
          break;
        default:  //the catch-all for this is to just bail out (undefined or null or whatever)
          vaProxy.WriteToLog("VoiceAttack ATAP.Utilities.VoiceAttack Plugin Error: \"" + iVal + "\" is not a known command", "red");
          break;
      }

      //This function is where you will do all of your work.  When VoiceAttack encounters an, 'Execute External Plugin Function' action, the plugin indicated will be called.
      //in previous versions, you were presented with a long list of parameters you could use.  The parameters have been consolidated in to one dynamic, 'vaProxy' parameter.

      //vaProxy.Context - a string that can be anything you want it to be.  this is passed in from the command action.  this was added to allow you to just pass a value into the plugin in a simple fashion (without having to set conditions/text values beforehand).  Convert the string to whatever type you need to.

      //vaProxy.SessionState - all values from the state maintained by VoiceAttack for this plugin.  the state allows you to maintain kind of a, 'session' within VoiceAttack.  this value is not persisted to disk and will be erased on restart. other plugins do not have access to this state (private to the plugin)

      //the SessionState dictionary is the complete state.  you can manipulate it however you want, the whole thing will be copied back and replace what VoiceAttack is holding on to


      //the following get and set the various types of variables in VoiceAttack.  note that any of these are nullable (can be null and can be set to null).  in previous versions of this interface, these were represented by a series of dictionaries

      //vaProxy.SetSmallInt and vaProxy.GetSmallInt - use to access short integer values (used to be called, 'conditions')
      //vaProxy.SetText and vaProxy.GetText - access text variable values
      //vaProxy.SetInt and vaProxy.GetInt - access integer variable values
      //vaProxy.SetDecimal and vaProxy.GetDecimal - access decimal variable values
      //vaProxy.SetBoolean and vaProxy.GetBoolean - access boolean variable values
      //vaProxy.SetDate and vaProxy.GetDate - access date/time variable values

      //to indicate to VoiceAttack that you would like a variable removed, simply set it to null.  all variables set here can be used withing VoiceAttack.
      //note that the variables are global (for now) and can be accessed by anyone, so be mindful of that while naming


      //if the, 'Execute External Plugin Function' command action has the, 'wait for return' flag set, VoiceAttack will wait until this function completes so that you may check condition values and
      //have VoiceAttack react accordingly.  otherwise, VoiceAttack fires and forgets and doesn't hang out for extra processing.


      //below is just some sample code showing how to work with vaProxy.  There's more in the VoiceAttack help documentation that is installed with VoiceAttack (VoiceAttackHelp.pdf).

      if (vaProxy.GetText("myCSharpTestValue") != null) //was the text value passed set?
      {
        vaProxy.SetText("myCSharpTestValue",
          "hello " + new Random().Next(1, 6)
            .ToString()); //if the value is not null, this is a subsequent call... just change up the value to nonsense.  this value will go back to VoiceAttack (perhaps to be read with TTS or whatever)
      }
      else //value has not been set.  set it here
      {
        vaProxy.SetText("myCSharpTestValue", "this is new");
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
    }
  }
}
