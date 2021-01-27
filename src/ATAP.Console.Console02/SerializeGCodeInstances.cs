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

    void SerializeAndSaveMultipleGGenerateCodeInstances(IPersistence<IInsertResultsAbstract> persistence = default) {
      Logger.LogDebug(DebugLocalizer["{0} {1}: Creating JSON from a Signil"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances");

      #region SerializerOptions for all calls to Serialize used by this method
      // Create a new options from the current Serializer options, and change write-indented to true, for all of the LpgDebug statements

      var options = new SerializerOptions() {
        WriteIndented = true,
      };
      #endregion

      #region Philote Serialization
      var philoteOfTypeInvokeGenerateCodeSignil = new Philote<GGlobalSettingsSignil>();
      var philoteOfTypeInvokeGenerateCodeSignilAsString = Serializer.Serialize(philoteOfTypeInvokeGenerateCodeSignil, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: philoteOfTypeInvokeGenerateCodeSignilAsString = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", philoteOfTypeInvokeGenerateCodeSignilAsString);
      ProgressObject!.Report(UiLocalizer["The default constructor of {0} = {1}", "new Philote<GGlobalSettingsSignil>()", philoteOfTypeInvokeGenerateCodeSignilAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      var insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"philoteOfTypeInvokeGenerateCodeSignil", new List<string>() {philoteOfTypeInvokeGenerateCodeSignilAsString}}
       });
      #endregion
      #region GComment Serialization (default)
      IGComment gComment = new GComment();
      var gCommentAsString = Serializer.Serialize(gComment, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gComment = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gCommentAsString);
      ProgressObject!.Report(UiLocalizer["The default constructor  {0} = {1}", "new GComment()", gCommentAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gCommentDefault", new List<string>() {gCommentAsString}}
       });
      #endregion
      #region GComment Serialization (with data)
      gComment = new GComment(new List<string>() { "This is a GComment, line1", "This is a GComment line, line2" });
      gCommentAsString = Serializer.Serialize(gComment, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gComment = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gCommentAsString);
      ProgressObject!.Report(UiLocalizer["The constructor  {0} = {1}", "new GComment(new List<string>())", gCommentAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gCommentWithData", new List<string>() {gCommentAsString}}
       });
      #endregion
      #region GBody Serialization (default)
      IGBody gBody = new GBody();
      var gBodyAsString = Serializer.Serialize(gBody, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gBody = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gBodyAsString);
      ProgressObject!.Report(UiLocalizer["The default constructor  {0} = {1}", "new GBody()", gBodyAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gBodyDefault", new List<string>() {gBodyAsString}}
       });
      #endregion
      #region GBody Serialization (with Data)
      gBody = new GBody(new List<string>() { "Body Line 1", "BodyLine 2" });
      gBodyAsString = Serializer.Serialize(gBody, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gBody = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gBodyAsString);
      ProgressObject!.Report(UiLocalizer["The default constructor  {0} = {1}", "new GBody(newList() {{stuff})", gBodyAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gBodyWithData", new List<string>() {gBodyAsString}}
       });
      #endregion
      #region GAssemblyUnit Serialization (default)
      IGAssemblyUnit gAssemblyUnit = new GAssemblyUnit();
      var gAssemblyUnitAsString = Serializer.Serialize(gAssemblyUnit, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyUnit = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gAssemblyUnitAsString);
      ProgressObject!.Report(UiLocalizer["The default constructor  {0} = {1}", "new GAssemblyUnit()", gAssemblyUnitAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gAssemblyUnitDefault", new List<string>() {gAssemblyUnitAsString}}
       });
      #endregion
      #region GAssemblyUnit Serialization (With Data)
      gAssemblyUnit = new GAssemblyUnit(
        gName: "ATAP.Console.Console01-Mechanical"
            // ToDo:  Add GDescription to the AssemblyUnit, gDescription: "mechanically generated AssemblyUnit For Console01"
        , gPatternReplacement: new GPatternReplacement(
            gName: "gPatternReplacementAssemblyUnitForATAP.Console.Console01-Mechanical"
            , new Dictionary<System.Text.RegularExpressions.Regex, string>()
            , gComment: new GComment(new List<string>() { "Pattern replacement Dictionary for the gAssemblyUnit having gName = ATAP.Console.Console01-Mechanical" }))
        , gComment: new GComment(new List<string>() { "Primary executable AssemblyUnit for the mechanically generated version of Console01" })
      );
      gAssemblyUnitAsString = Serializer.Serialize(gAssemblyUnit, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyUnit = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gAssemblyUnitAsString);
      ProgressObject!.Report(UiLocalizer["The constructor  {0} = {1}", "new GAssemblyUnit(stuff)", gAssemblyUnitAsString]);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gAssemblyUnitWithData", new List<string>() {gAssemblyUnitAsString}}
       });
      #endregion


      #region GAssemblyGroupSignil Serialization (default)
      IGAssemblyGroupSignil gAssemblyGroupSignil = new GAssemblyGroupSignil(
      );
      var gAssemblyGroupSignilAsString = Serializer.Serialize(gAssemblyGroupSignil, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyGroupSignil (default) = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gAssemblyGroupSignilAsString);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gAssemblyGroupSignilDefault", new List<string>() {gAssemblyGroupSignilAsString}}
       });
      #endregion
      #region GAssemblyGroupSignil Serialization (with data)
      gAssemblyGroupSignil = new GAssemblyGroupSignil(
        gName: "ATAP.Console.Console01-Mechanical"
        , gDescription: "mechanically generated AssemblyGroup For Console01"
        , gRelativePath: ".\\"
        , gAssemblyUnits: new Dictionary<IPhilote<IGAssemblyUnit>, IGAssemblyUnit>() { }
        , gPatternReplacement: new GPatternReplacement(
            gName: "gPatternReplacementAssemblyGroupForATAP.Console.Console01-Mechanical"
            , new Dictionary<System.Text.RegularExpressions.Regex, string>()
            , gComment: new GComment(new List<string>() { "Pattern replacement Dictionary for the gAssemblyGroup having gName = ATAP.Console.Console01-Mechanical" }))
        , gComment: new GComment(new List<string>() { "Primary executable AssemblyGroup for the mechanically generated version of Console01" })
        , hasInterfacesAssembly: false
      );
      gAssemblyGroupSignilAsString = Serializer.Serialize(gAssemblyGroupSignil, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gAssemblyGroupSignil (with data) = {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gAssemblyGroupSignilAsString);
      //ToDo: wrap in try/catch, handle failure of Persistence InsertFunc
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gAssemblyGroupSignilWithData", new List<string>() {gAssemblyGroupSignilAsString}}
       });
      #endregion

      var _defaultTargetFrameworks = new List<string>() { "netstandard2.1;", "net5.0" };

      #region GSolutionSignil Serialization (default)
      var _buildConfigurations = new SortedSet<string>() { "Debug", "ReleaseWithTrace", "Release" };
      var _cPUConfigurations = new SortedSet<string>() { "Any CPU" };
      var _gDependencyPackages = new Dictionary<IPhilote<IGProjectUnit>, IGProjectUnit>();
      var _gDependencyProjects = new Dictionary<IPhilote<IGProjectUnit>, IGProjectUnit>();
      var _gProjectUnits = new Dictionary<IPhilote<IGProjectUnit>, IGProjectUnit>();
      var _gComment = new GComment(new List<string>() { "ToDo: add SolutionSignil Comments here" });
      IGSolutionSignil gSolutionSignilFromCode = new GSolutionSignil(
        hasPropsAndTargets: true
        , hasEditorConfig: true
        , hasArtifacts: true
        , hasDevLog: true
        , sourceRelativePath: "src"
        , testsRelativePath: "tests"
        , hasOmniSharpConfiguration: true
        , hasVisualStudioCodeWorkspaceConfiguration: true
        , buildConfigurations: _buildConfigurations
        , cPUConfigurations: _cPUConfigurations
        , gDependencyPackages: _gDependencyPackages
        , gDependencyProjects: _gDependencyProjects
        , gComment: _gComment
      );
      var gSolutionSignilFromCodeAsSettingsString = Serializer.Serialize(gSolutionSignilFromCode, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gSolutionSignilFromCode in JSON {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gSolutionSignilFromCodeAsSettingsString);
      ProgressObject!.Report(UiLocalizer["The default constructor of {0} = {1}", "new GSolutionSignil(defaultTargetFrameworks)", gSolutionSignilFromCodeAsSettingsString]);
      // write string to persistence file keyed by gGlobalSettingsSignilFromCodeAsSettings
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gSolutionSignilFromCodeAsSettings", new List<string>() {gSolutionSignilFromCodeAsSettingsString}}
       });
      // ToDo: Test for and handle failure of Persistence InsertFunc
      #endregion


      #region GInvokeGenerateCodeSignil to JSON string
      IGInvokeGenerateCodeSignil gInvokeGenerateCodeSignil = new GInvokeGenerateCodeSignil(
        gAssemblyGroupSignil: gAssemblyGroupSignil
        //, gGlobalSettingsSignil: gGlobalSettingsSignilFromCode
        , gSolutionSignil: gSolutionSignilFromCode
      );
      var gInvokeGenerateCodeSignilAsString = Serializer.Serialize(gInvokeGenerateCodeSignil, options);
      Logger.LogDebug(DebugLocalizer["{0} {1}: gInvokeGenerateCodeSignil in JSON {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gInvokeGenerateCodeSignilAsString);
      // write string to persistence file keyed by gGlobalSettingsSignilFromCodeAsSettings
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gInvokeGenerateCodeSignil", new List<string>() {gInvokeGenerateCodeSignilAsString}}
       });
      // ToDo: Test for and handle failure of Persistence InsertFunc
      #endregion

      /*
      #region GGlobalSettingsSignil to JSON string
      IGGlobalSettingsSignil gGlobalSettingsSignilFromCode = new GGlobalSettingsSignil(
        defaultTargetFrameworks: _defaultTargetFrameworks
      );
      var gGlobalSettingsSignilFromCodeAsSettingsString = Serializer.Serialize(gGlobalSettingsSignilFromCode, options);
      //Logger.LogDebug(DebugLocalizer["{0} {1}: SignilFromCode in JSON {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gGlobalSettingsSignilFromCode.Dump());
      Logger.LogDebug(DebugLocalizer["{0} {1}: gGlobalSettingsSignilFromCode in JSON {2}"], "Console02BackgroundService", "SerializeAndSaveMultipleGGenerateCodeInstances", gGlobalSettingsSignilFromCodeAsSettingsString);
      ProgressObject!.Report(UiLocalizer["The default constructor of {0} = {1}", "new GGlobalSettingsSignil(defaultTargetFrameworks)", gGlobalSettingsSignilFromCodeAsSettingsString]);
      // write string to persistence file keyed by gGlobalSettingsSignilFromCodeAsSettings
      insertResults = PersistenceObject.InsertDictionaryFunc(new Dictionary<string, IEnumerable<object>>() {
        {"gGlobalSettingsSignilFromCodeAsSettings", new List<string>() {gGlobalSettingsSignilFromCodeAsSettingsString}}
       });
      // ToDo: Test for and handle failure of Persistence InsertFunc
      #endregion


      */
    }
  }
}
