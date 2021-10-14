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
using CollectionExtensions = ATAP.Utilities.Collection.Extensions;
using ConfigurationExtensions = ATAP.Utilities.Configuration.Extensions;

using StringConstantsVAGameAOE = ATAP.Utilities.VoiceAttack.Game.AOE.StringConstants;
using StringConstantsVAGame = ATAP.Utilities.VoiceAttack.Game.StringConstants;
using StringConstantsVA = ATAP.Utilities.VoiceAttack.StringConstantsVA;
using StringConstantsGenericHost = ATAP.Utilities.VoiceAttack.StringConstantsGenericHost;

using ATAP.Utilities.HostedServices;


namespace ATAP.Utilities.VoiceAttack.Game.AOE.II {

  public class Plugin : ATAP.Utilities.VoiceAttack.Game.AOE.Plugin {

    public new static ATAP.Utilities.VoiceAttack.Game.AOE.II.Data Data { get; set; }
    public new static string VA_DisplayName() {
      var str = "ATAP Utilities Plugin for VAGamesAOEII V0.1.0-alpha01\r\n" + ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.VA_DisplayName();
      return str;
    }

    public new static string VA_DisplayInfo() {
      var str = "ATAP Utilities Plugin VAGameAOEII \r\n\r\n" + ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.VA_DisplayInfo();
      return str;
    }

    public new static Guid VA_Id() {
      return
        new Guid("{0E8258DD-54C7-4794-A1EB-F3368D769996}"); //
    }

    static Boolean _stopVariableToMonitor = false;

    // this function is called from VoiceAttack when the 'stop all commands' button is pressed or a, 'stop all commands' action is called.
    public new static void VA_StopCommand() {
      _stopVariableToMonitor = true;
    }

    // the plugin interface has only a single dynamic parameter.
    public new static void VA_Init1(dynamic vaProxy) {
      // Configure a startup Logger, prior to getting the Logger configuration from the ConfigurationRoot
      InitializeLogger();
      Serilog.Log.Debug("{0} {1}: VA_Init1 received at {2}", "PluginVAGameAOEII", "VA_Init1", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.VA_Init1((object)vaProxy);
      // Traverse the inheritance chain, accumulate the config sections at each level
      var configSections = GetConfigurationSections();
      #region initial ConfigurationBuilder and ConfigurationRoot
      // Create the final ConfigurationRoot, taking into account all environments, default values, settings files, and environment variables This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      ConfigurationRoot configurationRoot = (ConfigurationRoot)GetConfigurationRootFromConfigurationSections(configSections);
      // Create the Data object (most specific of the inheritance tree)
      Data = new ATAP.Utilities.VoiceAttack.Game.AOE.II.Data(configurationRoot, vaProxy);
      SetData((IData) Data);
      InitializeData((object) vaProxy);
      AttachToMainTimer((o, e) => {
        // If PresentOnPriorityQueue
        //If PresentOnNormalQueue
        // Write message to user via vaProxy
        vaProxy.WriteToLog($"MainTimerFired, {Data.MainTimerElapsedTimeSpan.ToString(StringConstantsVA.DATE_FORMAT)}  {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");
        Serilog.Log.Debug("{0} {1}: MainTimerFired at {2}", "MainTimerFired", "MainTimerDelegate", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      });
    }

    public new static void VA_Exit1(dynamic vaProxy) {
      //this function gets called when VoiceAttack is closing (normally).
      // Dispose of the Data structure and all it contains
      ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.VA_Exit1((object)vaProxy);
      Data.Dispose();
    }

    public new static void VA_Invoke1(dynamic vaProxy) {

      string iVal = vaProxy.Context;

      Serilog.Log.Debug("{0} {1}: {2} command received at {3}", "PluginVAGameAOEII", "VA_Invoke1", iVal, DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      vaProxy.WriteToLog($"{iVal} command received by PluginVAGameAOEII at {DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT)}", "blue");

      switch (iVal) {
        default:  //the catch-all for an unrecognized Context is send it down one layer in the plugin stack
          ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.VA_Invoke1((object)vaProxy);
          vaProxy.WriteToLog("VoiceAttack ATAP.Utilities.VoiceAttack Plugin Error: \"" + iVal + "\" is not a known command", "red");
          break;
      }
    }

    #region
    public static void AttachToMainTimer(Action<object, EventArgs> DoSomething) {
      // Attach the action specified as a method parameter to the main timer
      // Data.TimerDisposeHandles[StringConstantsVA.MainTimerName].Subscribe(DoSomething);

    }
    #endregion
    #region Traverse the inheritance chain and get the various configurationSections from each
    public static new (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      Serilog.Log.Debug("{0} {1}: GetConfigurationSections Enter at {2}", "PluginVAGameAOEII", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.GetConfigurationSections();
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.AddRange(lDCs);
      SettingsFiles.AddRange(lSFTs);
      CustomEnvironmentVariablePrefixs.AddRange(lEVPs);
      DefaultConfigurations.Add(ATAP.Utilities.VoiceAttack.Game.AOE.II.DefaultConfiguration.Production);
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));

      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion

    #region Build the configurationRoot
    public static IConfigurationRoot GetConfigurationRootFromConfigurationSections((List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) configSections) {
      bool isProduction = true; //Initial pass
      string? envNameFromConfiguration = StringConstantsGenericHost.EnvironmentProduction;
      #region initialStartup and loadedFrom directories
      // When running as a Windows service, the initial working dir is usually %WinDir%\System32, but the program (and configuration files) is probably installed to a different directory
      // When running as a *nix service, the initial working dir could be anything. The program (and machine-wide configuration files) are probably installed in the location where the service starts. //ToDo: verify this
      // When running as a Windows or Linux Console App, the initial working dir could be anything, but the program (and machine-wide configuration files) is probably installed to a different directory.
      // When running as a console app, it is very possible that there may be local (to the initial startup directory) configuration files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      var initialStartupDirectory = Directory.GetCurrentDirectory(); //ToDo: Catch exceptions
      Serilog.Log.Debug("{0} {1}: initialStartupDirectory: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", initialStartupDirectory);
      var loadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); //ToDo: Catch exceptions
      Serilog.Log.Debug("{0} {1}: loadedFromDirectory: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", loadedFromDirectory);
      #endregion
      #region Initial ConfigurationRoot
      ConfigurationBuilder configurationBuilder = (ConfigurationBuilder)ConfigurationExtensions.ATAPStandardConfigurationBuilder(isProduction, envNameFromConfiguration, configSections, loadedFromDirectory, initialStartupDirectory);
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
      envNameFromConfiguration = configurationRoot.GetValue<string>(StringConstantsGenericHost.EnvironmentConfigRootKey, StringConstantsGenericHost.EnvironmentDefault);
      Serilog.Log.Debug("{0} {1}: Initial environment name: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", envNameFromConfiguration);

      // optional: Validate that the environment provided is one this program understands how to use
      // Accepting any string for envNameFromConfiguration might pose a security risk, as it will allow arbitrary files to be loaded into the configuration root
      switch (envNameFromConfiguration) {
        case StringConstantsGenericHost.EnvironmentDevelopment:
          // ToDo: Programmers can add things here
          break;
        case StringConstantsGenericHost.EnvironmentProduction:
          // This is the expected leg for Production environment
          break;
        default:
          // IF you want to accept any environment name as OK, just comment out the following throw
          // Keep the throw in here if you want to explicitly disallow any environment other than ones specified in the switch
          throw new NotImplementedException($"The Environment {envNameFromConfiguration} is not supported");
      };
      #endregion

      #region final (Environment-aware) configurationBuilder and appConfigurationBuilder
      // If the initial configurationRoot specifies the Environment is production, then the configurationRoot is correct  "as-is"
      //   but if not, build a 2nd (final) configurationBuilder, this time including environment-specific configuration providers
      if (envNameFromConfiguration != StringConstantsGenericHost.EnvironmentProduction) {
        // Recreate the ConfigurationBuilder for this overall plugin, this time including environment-specific configuration providers.
        Serilog.Log.Debug("{0} {1}: Recreating configurationBuilder for Environment: {2}", "PluginVAGameAOEII", "GetConfigurationRootFromConfigurationSections", envNameFromConfiguration);

        configurationBuilder = (ConfigurationBuilder)ConfigurationExtensions.ATAPStandardConfigurationBuilder(isProduction, envNameFromConfiguration, configSections, loadedFromDirectory, initialStartupDirectory);

        // Create this program's final ConfigurationRoot from the 2nd (final) configurationBuilder
        configurationRoot = configurationBuilder.Build();

      }
      #endregion
      return configurationRoot;
    }
    #endregion
        #region Populate the Data Property
    public static void SetData(IData newData) {
      Data = (Data) newData;
      ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.SetData(newData);
    }
    #endregion

    #region Initialize the Data's Autoproperties
    public static void InitializeData(dynamic vaProxy) {
      Serilog.Log.Debug("{0} {1}: InitializeData Enter at {2}", "PluginVAGameAOEII", "InitializeData", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      // Copy a reference to this data object down the inheritance tree)
      ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.SetData(Data);

      // Populate the properties of the Data object, including Current values of objects from Configuration items
      ATAP.Utilities.VoiceAttack.Game.AOE.Plugin.InitializeData();
    }
    #endregion



  }
}
#endregion
