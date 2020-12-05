using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Collection;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GMacroExtensions;
using static GenerateProgram.GArgumentExtensions;
using static GenerateProgram.Lookup;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    public static MCreateAssemblySingleResult MAssemblySingleBasicConstructor(string gTitularAssemblyName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default,
      GPatternReplacement gPatternReplacement = default) {
      GPatternReplacement _gPatternReplacement =
        gPatternReplacement == default ? new GPatternReplacement() : gPatternReplacement;

      #region Determine the names of the Titular Base and Derived CompilationUnits, Namespaces, Classes
      // everything to the right of the last "." character, returns original string if no "."
      var pos = gTitularAssemblyName.LastIndexOf(".") + 1;
      var gTitularCommonName = gTitularAssemblyName.Substring(pos, gTitularAssemblyName.Length - pos);
      var gTitularAssemblyUnitName = gTitularAssemblyName;
      var gNamespaceName = $"{baseNamespaceName}{gTitularCommonName}";
      var gCompilationUnitCommonName = gTitularCommonName;
      var gTitularDerivedCompilationUnitName = gCompilationUnitCommonName;
      var gTitularBaseCompilationUnitName = gCompilationUnitCommonName + "Base";
      var gClassDerivedName = gCompilationUnitCommonName;
      var gClassBaseName = gCompilationUnitCommonName + "Base";





      #endregion
      #region GReplacementPatternDictionary for the GTitularAssembly
      var gTitularAssemblyPatternReplacement = new GPatternReplacement(gName: "gTitularAssemblyPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("AssemblyUnitNameReplacementPattern"), gTitularAssemblyName},
        });
      // add the PatternReplacements specified as the gPatternReplacement argument
      foreach (var kvp in gPatternReplacement.GDictionary) {
        gTitularAssemblyPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the GTitularAssembly
      var gTitularAssembly = new GAssemblySingle(new GAssemblySingleSignil(gName: gTitularAssemblyName, gPatternReplacement: gTitularAssemblyPatternReplacement));
      #endregion
      #region ProjectUnit for the Titular AssemblyUnit
      #region GPatternReplacement for the ProjectUnit
      var gGTitularAssemblyProjectUnitPatternReplacement =
        new GPatternReplacement(gName: "GTitularAssemblyProjectUnitPatternReplacement");
      gGTitularAssemblyProjectUnitPatternReplacement.GDictionary.AddRange(
        gTitularAssemblyPatternReplacement.GDictionary);
      #endregion
      var gGTitularAssemblyProjectUnit = new GProjectUnit(gName: gTitularAssemblyName,
        gPatternReplacement: gGTitularAssemblyProjectUnitPatternReplacement);
      #endregion
      #region Titular Derived CompilationUnit
      #region Pattern Replacements for Titular Derived CompilationUnit
      var gTitularDerivedCompilationUnitPatternReplacement = new GPatternReplacement(gName: "gTitularDerivedCompilationUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularDerivedCompilationUnitName},
        });
      // add the AssemblyUnit PatternReplacements to the Derived CompilationUnit PatternReplacements
      gTitularDerivedCompilationUnitPatternReplacement.GDictionary.AddRange(gTitularAssemblyPatternReplacement
        .GDictionary);
      #endregion
      #region Instantiate the Titular Derived CompilationUnit
      var gTitularDerivedCompilationUnit = new GCompilationUnit(gTitularDerivedCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gTitularDerivedCompilationUnitPatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gTitularDerivedCompilationUnit.Philote, gTitularDerivedCompilationUnit);
      #region Instantiate the gNamespaceDerived
      var gNamespaceDerived = new GNamespace(gNamespaceName);
      #endregion
      gTitularDerivedCompilationUnit.GNamespaces.Add(gNamespaceDerived.Philote, gNamespaceDerived);
      #region Instantiate the gClassDerived
      var gClassDerived = new GClass(gClassDerivedName, "public", gAccessModifier: "partial",
        gInheritance: gClassBaseName
      //gImplements: new List<string> {} //"IDisposable",
      //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternDerivedData" }
      );
      #endregion
      gNamespaceDerived.GClasss.Add(gClassDerived.Philote, gClassDerived);
      #endregion

      #region Titular Base CompilationUnit
      #region Pattern Replacements for Derived CompilationUnit
      var gTitularBaseCompilationUnitPatternReplacement = new GPatternReplacement(gName: "gTitularBaseCompilationUnitPatternReplacement",
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), gTitularBaseCompilationUnitName},
          //{new Regex("DataInitializationReplacementPattern"), tempdatainitialization}, {
          //  new Regex("DataDisposalReplacementPattern"),
          //  //"SubscriptionToConsoleReadLineAsyncAsObservableDisposeHandle.Dispose();"
          //  ""
          //},
        });
      // add the AssemblyUnit PatternReplacements to the Base CompilationUnit PatternReplacements
      foreach (var kvp in gTitularAssemblyUnitPatternReplacement.GDictionary) {
        gTitularBaseCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }
      #endregion
      #region Instantiate the Titular Base CompilationUnit
      var gTitularBaseCompilationUnit = new GCompilationUnit(gTitularBaseCompilationUnitName, gFileSuffix: ".cs",
        gRelativePath: subDirectoryForGeneratedFiles, gPatternReplacement: gTitularBaseCompilationUnitPatternReplacement);
      #endregion
      gTitularAssemblyUnit.GCompilationUnits.Add(gTitularBaseCompilationUnit.Philote, gTitularBaseCompilationUnit);
      #region Instantiate the gNamespaceBase
      var gNamespaceBase = new GNamespace(gNamespaceName);
      #endregion
      gTitularBaseCompilationUnit.GNamespaces.Add(gNamespaceBase.Philote, gNamespaceBase);
      #region Instantiate the gClassBase
      var gClassBase = new GClass(gClassBaseName, "public", gAccessModifier: "partial"
      //gInheritance: baseClass.GName
      //gImplements: new List<string> {} //, "IDisposable"
      //gDisposesOf: new List<string> { "CompilationUnitNameReplacementPatternBaseData" }
      );
      #endregion
      gNamespaceBase.GClasss.Add(gClassBase.Philote, gClassBase);
      #region Instantiate the gPrimaryConstructorBase (Primary Constructor for the Titular Base Class)
      var gPrimaryConstructorBase = new GMethod(new GMethodDeclaration(gClassBaseName, isConstructor: true,
        gVisibility: "public"));
      #endregion
      gClassBase.GMethods.Add(gPrimaryConstructorBase.Philote, gPrimaryConstructorBase);
      #endregion
      //#region Data Initialization (startup?)
      //// ToDo: encapsulate and refactor
      //string tempdatainitialization = @"
      //  /*
      //  #region configurationRoot for this HostedService
      //  // Create the configurationBuilder for this HostedService. This creates an ordered chain of configuration providers. The first providers in the chain have the lowest priority, the last providers in the chain have a higher priority.
      //  // The Environment has been configured by the GenericHost before this point is reached
      //  // InitialStartupDirectory has been set by the GenericHost before this point is reached, and is where the GenericHost program or service was started
      //  // LoadedFromDirectory has been configured by the GenericHost before this point is reached. It is the location where this assembly resides
      //  // ToDo: Implement these two values into the GenericHost configurationRoot somehow, then remove from the constructor signature
      //  // var loadedFromDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\); //ToDo suport dynamic assembly loading form other Startup directories -  Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
      //  // var initialStartupDirectory = hostConfiguration.GetValue<string>(\SomeStringConstantConfigrootKey\ \./\);
      //  // Build the configurationRoot for this service
      //  // var configurationBuilder = ConfigurationExtensions.StandardConfigurationBuilder(loadedFromDirectory, initialStartupDirectory, ConsoleMonitorDefaultConfiguration.Production, ConsoleMonitorStringConstants.SettingsFileName, ConsoleMonitorStringConstants.SettingsFileNameSuffix, StringConstants.CustomEnvironmentVariablePrefix, LoggerFactory, stringLocalizerFactory, hostEnvironment, hostConfiguration, linkedCancellationToken);
      //  // ConfigurationRoot = configurationBuilder.Build();
      //  #endregion
      //  // Embedded object as Data 
      //  //AssemblyUnitNameReplacementPatternBaseData = new AssemblyUnitNameReplacementPatternBaseData();
      //  */";
      //#endregion


      /* ************************************************************************************ */

      MCreateAssemblySingleResult mCreateAssemblySingleResult = new MCreateAssemblySingleResult() {
        subDirectoryForGeneratedFiles = subDirectoryForGeneratedFiles,
        baseNamespaceName = baseNamespaceName,
        gAssemblySingleName = gAssemblySingleName,
        gTitularAssemblyUnitName = gTitularAssemblyUnitName,
        gTitularBaseCompilationUnitName = gTitularBaseCompilationUnitName,
        gAssemblySingle = gAssemblySingle,
        gAssemblySinglePatternReplacement = gAssemblySinglePatternReplacement,
        gTitularAssemblyUnit = gTitularAssemblyUnit,
        gTitularAssemblyUnitPatternReplacement = gTitularAssemblyUnitPatternReplacement,
        gTitularDerivedCompilationUnit = gTitularDerivedCompilationUnit,
        gTitularDerivedCompilationUnitPatternReplacement = gTitularDerivedCompilationUnitPatternReplacement,
        gTitularBaseCompilationUnit = gTitularBaseCompilationUnit,
        gTitularBaseCompilationUnitPatternReplacement = gTitularBaseCompilationUnitPatternReplacement,
        gNamespaceDerived = gNamespaceDerived,
        gNamespaceBase = gNamespaceBase,
        gClassBase = gClassBase,
        gClassDerived = gClassDerived,
        gPrimaryConstructorBase = gPrimaryConstructorBase
      };
      return mCreateAssemblySingleResult;
    }
    public static GAssemblySingle MAssemblySingleStringConstants(
      (string subDirectoryForGeneratedFiles,
        string baseNamespaceName,
        string gAssemblySingleName,
        string gAssemblyUnitName,
        string gCompilationUnitName,
        GPatternReplacement gAssemblySinglePatternReplacement,
        GPatternReplacement gAssemblyUnitPatternReplacement,
        GPatternReplacement gCompilationUnitPatternReplacement,
        GAssemblySingle gAssemblySingle,
        GAssemblyUnit gAssemblyUnit,
        GCompilationUnit gCompilationUnit,
        GNamespace gNamespace) part1Tuple,
      GClass gClass
    ) {
      return MAssemblySingleStringConstants(
        part1Tuple.subDirectoryForGeneratedFiles,
        part1Tuple.baseNamespaceName,
        part1Tuple.gAssemblySingleName,
        part1Tuple.gAssemblyUnitName,
        part1Tuple.gCompilationUnitName,
        part1Tuple.gAssemblySinglePatternReplacement,
        part1Tuple.gAssemblyUnitPatternReplacement,
        part1Tuple.gCompilationUnitPatternReplacement,
        part1Tuple.gAssemblySingle,
        part1Tuple.gAssemblyUnit,
        part1Tuple.gCompilationUnit,
        part1Tuple.gNamespace,
        gClass
      );
    }
    public static GAssemblySingle MAssemblySingleStringConstants(MCreateAssemblySingleResult mCreateAssemblySingleResult) {
      return MAssemblySingleStringConstants(
        mCreateAssemblySingleResult.subDirectoryForGeneratedFiles,
        mCreateAssemblySingleResult.baseNamespaceName,
        mCreateAssemblySingleResult.gAssemblySingleName,
        mCreateAssemblySingleResult.gAssemblySingleName,
        mCreateAssemblySingleResult.gTitularBaseCompilationUnitName,
        mCreateAssemblySingleResult.gAssemblySinglePatternReplacement,
        mCreateAssemblySingleResult.gAssemblyUnitPatternReplacement,
        mCreateAssemblySingleResult.gCompilationUnitPatternReplacement,
        mCreateAssemblySingleResult.gAssemblySingle,
        mCreateAssemblySingleResult.gAssemblyUnit,
        mCreateAssemblySingleResult.gTitularBaseCompilationUnit,
        mCreateAssemblySingleResult.gNamespaceBase
        //gClass
      );
    }
    public static GAssemblySingle MAssemblySingleStringConstants(
      string subDirectoryForGeneratedFiles = default,
      //string baseNamespaceName = default,
      //string gAssemblySingleName = default,
      //string gAssemblyUnitName = default,
      //string gCompilationUnitName = default,
     // GPatternReplacement gAssemblySinglePatternReplacement = default,
      GPatternReplacement gAssemblyUnitPatternReplacement = default,
      //GPatternReplacement gCompilationUnitPatternReplacement = default,
      GAssemblySingle gAssemblySingle = default,
      GAssemblyUnit gAssemblyUnit = default,
      //GCompilationUnit gCompilationUnit = default,
      GNamespace gNamespace = default
      //GClass gClass = default
    ) {
      GUsingGroup gUsingGroup;
      GPropertyGroup gPropertyGroup;
      #region StringConstants Base CompilationUnit
      var gCompilationUnitPatternReplacement = new GPatternReplacement(
        gDictionary: new Dictionary<Regex, string>() {
          {new Regex("CompilationUnitNameReplacementPattern"), "AssemblyUnitNameReplacementPattern"}
        });
      foreach (var kvp in gAssemblyUnitPatternReplacement.GDictionary) {
        gCompilationUnitPatternReplacement.GDictionary.Add(kvp.Key, kvp.Value);
      }

      #region Additional StringConstants items
      var gAdditionalStatements = new List<string>() { "{dummyConfigKeyRoot,dummyConfigDefaultString}" };
      #endregion
      var gCompilationUnit = CompilationUnitStringConstantsConstructor(gNamespaceName: gNamespace.GName,
        gRelativePath: subDirectoryForGeneratedFiles,
        gPatternReplacement: gCompilationUnitPatternReplacement);
      gAssemblyUnit.GCompilationUnits.Add(gCompilationUnit.Philote, gCompilationUnit);
      #endregion
      return gAssemblySingle;
    }
    public static void MUpdateGPatternReplacement(GAssemblySingle gAssemblySingle,
      GPatternReplacement gAssemblySinglePatternReplacement) {
      gAssemblySingle.GAssemblySingleSignil.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement.GDictionary);
      foreach (var gAssemblyUnitKVP in gAssemblySingle.GAssemblySingleSignil.GAssemblyUnits) {
        gAssemblyUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement.GDictionary);
        gAssemblyUnitKVP.Value.GProjectUnit.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement
          .GDictionary);
        foreach (var gCompilationUnitKVP in gAssemblyUnitKVP.Value.GCompilationUnits) {
          gCompilationUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement
            .GDictionary);
        }
        foreach (var gResourceUnitKVP in gAssemblyUnitKVP.Value.GResourceUnits) {
          gResourceUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement.GDictionary);
        }
        //foreach (var gPropertiesUnitKVP in gAssemblyUnitKVP.Value.GPropertiesUnits) {
        //  gPropertiesUnitKVP.Value.GPatternReplacement.GDictionary.AddRange(gAssemblySinglePatternReplacement.GDictionary);
        //}
      }
    }
  }
}
