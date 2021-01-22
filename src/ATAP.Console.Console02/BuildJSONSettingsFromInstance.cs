using ATAP.Utilities.ETW;
using ATAP.Utilities.HostedServices;
using ATAP.Utilities.HostedServices.ConsoleSinkHostedService;
using ATAP.Utilities.HostedServices.ConsoleSourceHostedService;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Logging;
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Reactive;
using ATAP.Utilities.GenerateProgram;
using ATAP.Services.GenerateCode;
using ATAP.Utilities.Serializer;


using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;

using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Reactive;
using System.Reactive.Linq;

using appStringConstants = ATAP.Console.Console02.StringConstants;
using generateProgramServiceStringConstants = ATAP.Services.GenerateCode.StringConstants;
using persistenceStringConstants = ATAP.Utilities.Persistence.StringConstants;

namespace ATAP.Console.Console02 {
  // This file contains the code to be executed in response to each selection by the user from the list of choices
  public partial class Console02BackgroundService : BackgroundService {

    void BuildJSONSettingsFromInstance(IProgress<object>? progress = default, IPersistence<IInsertResultsAbstract> persistence = default) {
      Logger.LogDebug(DebugLocalizer["{0} {1}: Creating JSON from a Signil"], "Console02BackgroundService", "BuildJSONSettingsFromInstance");

      #region SerializerOptions for all calls to Serialize used by this method
      // Create a new options from the current Serializer options, and change write-indented to true, for all of the LpgDebug statements

      var options = new SerializerOptions() {
        WriteIndented = true,
      };
      #endregion

      #region Philote Serialization
      var philoteOfTypeGGlobalSettingsSignil = new Philote<GGlobalSettingsSignil>();
      var philoteOfTypeGGlobalSettingsSignilAsString = Serializer.Serialize(philoteOfTypeGGlobalSettingsSignil, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: philoteOfTypeGGlobalSettingsSignilAsString in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", philoteOfTypeGGlobalSettingsSignilAsString);
      #endregion

      #region GGlobalSettingsSignil to JSON string
      var _defaultTargetFrameworks = new List<string>() { "netstandard2.1;", "net5.0" };
      IGGlobalSettingsSignil gGlobalSettingsSignilFromCode = new GGlobalSettingsSignil(
        defaultTargetFrameworks: _defaultTargetFrameworks
      );
      var gGlobalSettingsSignilFromCodeAsSettingsString = Serializer.Serialize(gGlobalSettingsSignilFromCode, options);
      //Logger.LogDebug(DebugLocalizer["{0} {1}: SignilFromCode in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", gGlobalSettingsSignilFromCode.Dump());
      Logger.LogDebug(DebugLocalizer["{0} {1}: gGlobalSettingsSignilFromCode in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", gGlobalSettingsSignilFromCodeAsSettingsString);
      #endregion

      #region GSolutionSignil to JSON string
      var _buildConfigurations = new SortedSet<string>() { "Debug", "ReleaseWithTrace", "Release" };
      var _cPUConfigurations = new SortedSet<string>() { "Any CPU" };
      var _gDependencyPackages = new Dictionary<IPhilote<IGProjectUnit>, IGProjectUnit>();
      var _gDependencyProjects = new Dictionary<IPhilote<IGProjectUnit>, IGProjectUnit>();
      IGSolutionSignil gSolutionSignilFromCode = new GSolutionSignil(
          buildConfigurations: _buildConfigurations
        , cPUConfigurations: _cPUConfigurations
        , gDependencyPackages: _gDependencyPackages
        , gDependencyProjects: _gDependencyProjects
      );
      var gSolutionSignilFromCodeAsSettingsString = Serializer.Serialize(gSolutionSignilFromCode, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gSolutionSignilFromCode in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", gSolutionSignilFromCodeAsSettingsString);
      #endregion

      #region GAssemblyGroupSignil to JSON string
      IGAssemblyGroupSignil gAssemblyGroupSignilFromCode = new GAssemblyGroupSignil(
      );
      var gAssemblyGroupSignilFromCodeAsSettingsString = Serializer.Serialize(gAssemblyGroupSignilFromCode, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyGroupSignilFromCode in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", gAssemblyGroupSignilFromCodeAsSettingsString);
      #endregion

      #region GInvokeGenerateCodeSignil to JSON string
      IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignilFromCode = new GInvokeGenerateCodeSignil(
        gAssemblyGroupSignil: gAssemblyGroupSignilFromCode
        , gGlobalSettingsSignil: gGlobalSettingsSignilFromCode
        , gSolutionSignil: gSolutionSignilFromCode
      );
      var gInvokeGenerateCodeSignilFromCodeAsSettingsString = Serializer.Serialize(gInvokeGenerateCodeSignilFromCode, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gInvokeGenerateCodeSignilFromCode in JSON {2}"], "Console02BackgroundService", "BuildJSONSettingsFromInstance", gInvokeGenerateCodeSignilFromCodeAsSettingsString);
      #endregion
    }
  }
}
