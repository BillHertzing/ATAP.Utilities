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
using ATAP.Utilities.Serializer.Interfaces;

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
using GenerateProgramServiceStringConstants = ATAP.Services.GenerateCode.StringConstants;
using PersistenceStringConstants = ATAP.Utilities.Persistence.StringConstants;

// Provides the .Dump utility to export complex .net objects into JSON
//using ServiceStack.Text;
using System.Text.Json;

namespace ATAP.Console.Console02 {
  // This file contains the code to be executed in response to each selection by the user from the list of choices
  public partial class Console02BackgroundService : BackgroundService {

    void BuildJSONSettingsFromInstance() {

      Logger.LogDebug(DebugLocalizer["{0} {1}: Creating JSON from a Signil"], "Console02BackgroundService", "DoLoopAsync");
      var options = new SerializerOptions
        {
            WriteIndented = true,
        };
      var _defaultTargetFrameworks = new List<string>() { "netstandard2.1;", "net5.0" };
      IGGlobalSettingsSignil gGlobalSettingsSignilFromCode = new GGlobalSettingsSignil(
        defaultTargetFrameworks: _defaultTargetFrameworks
      );
      var gGlobalSettingsSignilFromCodeAsSettingsString = JsonSerializer.Serialize(gGlobalSettingsSignilFromCode);
      //Logger.LogDebug(DebugLocalizer["{0} {1}: SignilFromCode in JSON {2}"], "Console02BackgroundService", "DoLoopAsync", gGlobalSettingsSignilFromCode.Dump());
      Logger.LogDebug(DebugLocalizer["{0} {1}: gGlobalSettingsSignilFromCode in JSON {2}"], "Console02BackgroundService", "DoLoopAsync", gGlobalSettingsSignilFromCodeAsSettingsString);

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
      var gSolutionSignilFromCodeAsSettingsString = JsonSerializer.Serialize(gSolutionSignilFromCode);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gSolutionSignilFromCode in JSON {2}"], "Console02BackgroundService", "DoLoopAsync", gSolutionSignilFromCodeAsSettingsString);

      IGAssemblyGroupSignil gAssemblyGroupSignilFromCode = new GAssemblyGroupSignil(
      );
      var gAssemblyGroupSignilFromCodeAsSettingsString = JsonSerializer.Serialize(gAssemblyGroupSignilFromCode);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyGroupSignilFromCode in JSON {2}"], "Console02BackgroundService", "DoLoopAsync", gAssemblyGroupSignilFromCodeAsSettingsString);

      IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignilFromCode = new GInvokeGenerateCodeSignil(
        gAssemblyGroupSignil: gAssemblyGroupSignilFromCode
        , gGlobalSettingsSignil : gGlobalSettingsSignilFromCode
        , gSolutionSignil: gSolutionSignilFromCode
      );
      var gInvokeGenerateCodeSignilFromCodeAsSettingsString = JsonSerializer.Serialize(gInvokeGenerateCodeSignilFromCode);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gInvokeGenerateCodeSignilFromCode in JSON {2}"], "Console02BackgroundService", "DoLoopAsync", gInvokeGenerateCodeSignilFromCodeAsSettingsString);
    }


}
}
