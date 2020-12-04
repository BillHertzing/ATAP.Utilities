using System;
using System.CodeDom;
using System.Collections.Generic;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Security.Permissions;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using ATAP.Utilities.Philote;
using static GenerateProgram.Lookup;
using static GenerateProgram.StringConstants;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.GAssemblyGroupExtensions;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GMacroExtensions;
using static ATAP.Utilities.Collection.Extensions;

//using AutoMapper.Configuration;

namespace GenerateProgram {
  class PService03 {
    delegate GAssemblyGroup MCreateAssemblyGroupDelegate(string name, string subDirectoryForGeneratedFiles,
      string baseNamespaceName);
    delegate GAssemblySingle MCreateAssemblySingleDelegate(string name, string subDirectoryForGeneratedFiles,
      string baseNamespaceName);

    static void Main(string[] args) {
      // ToDo: Get the Artifacts directory from the host
      string artifactsPath = "D:/Temp/GenerateProgramArtifacts/";
      // Source Code Directory and Tests Code Directory relative to the artifactsPath
      string sourceRelativePath = "src/";
      string sourceArtifactsPath = Path.Combine(artifactsPath, sourceRelativePath);
      string testRelativePath = "tests/";
      string testArtifactsPath = Path.Combine(artifactsPath, testRelativePath);
      string baseNamespaceName = "ATAP.Utilities.";



      var interfaces = ".Interfaces";
      string subDirectoryForGeneratedFiles = "Generated";


      #region Projects under development, their realtive paths under the source and tests directory, and the delegate to create each
      string genericHostProgramsRelativeNextPath = "GenericHostPrograms/";
      string genericHostProgramsRelativeNextNamespace = "GenericHostPrograms.";
      string gHPBaseNamespaceName = baseNamespaceName + genericHostProgramsRelativeNextNamespace;

      string genericHostServicesRelativeNextPath = "GenericHostServices/";
      string genericHostServicesRelativeNextNamespace = "GenericHostServices.";
      string gHSBaseNamespaceName = baseNamespaceName + genericHostServicesRelativeNextNamespace;
      (string name, string sourceRelativePath, string testRelativePath,
        string subDirectoryForGeneratedFiles,
        string baseNamespaceName, MCreateAssemblySingleDelegate
        mCreateAssemblySingleDelegate) gPrimaryExecutingProgram = 
      ("Service03",
        Path.Combine(sourceArtifactsPath, genericHostProgramsRelativeNextPath, "Service03/"),
        Path.Combine(testArtifactsPath, genericHostProgramsRelativeNextPath, "Service03/"),
        subDirectoryForGeneratedFiles, gHSBaseNamespaceName,
        new MCreateAssemblySingleDelegate(MGenericHostService03));

      var projectsUnderDevelopment =  new List<(string name, string sourceRelativePath, string testRelativePath, string subDirectoryForGeneratedFiles,
          string baseNamespaceName,MCreateAssemblyGroupDelegate
          mCreateAssemblyGroupDelegate )>() {
          ("ATAP.Utilities.Stateless", Path.Combine(sourceArtifactsPath, "StateMachine/"),
            Path.Combine(testArtifactsPath, "StateMachine/"), subDirectoryForGeneratedFiles, baseNamespaceName,
            new MCreateAssemblyGroupDelegate(MAUStateless)),

          ("TimerGHS", Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "TimerGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "TimerGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MTimerGHS)),

          ("FileSystemWatcherGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "FileSystemWatcherGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "FileSystemWatcherGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MFileSystemWatcherGHS)),

          ("ConsoleSourceGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleSourceGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleSourceGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MConsoleSourceGHS)),

          ("ConsoleSinkGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleSinkGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleSinkGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MConsoleSinkGHS)),

          ("ConsoleMonitorGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleMonitorGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "ConsoleMonitorGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MConsoleMonitorGHS)),

          ("TopLevelBackgroundGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "TopLevelBackgroundGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "TopLevelBackgroundGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MTopLevelBackgroundGHS)),

          ("FileSystemToObjectGraphGHS",
            Path.Combine(sourceArtifactsPath, genericHostServicesRelativeNextPath, "FileSystemToObjectGraphGHS/"),
            Path.Combine(testArtifactsPath, genericHostServicesRelativeNextPath, "FileSystemToObjectGraphGHS/"),
            subDirectoryForGeneratedFiles, gHSBaseNamespaceName ,
            new MCreateAssemblyGroupDelegate(MFileSystemToObjectGraphGHS)),
        };
      #endregion

      #region Conversion of nonReleased Packages from PacakgeReference to ProjectReference
      #region The structure of the project and package includes lines found in a ProjectUnit's ItemGroup
      var fromPatternP = "<PackageReference Include=\"";
      var fromPatternS = "\"\\s*/>";
      var toPatternP = "<ProjectReference Include=\"";
      var toPatternS = "\" />";
      #endregion

      List<KeyValuePair<Regex, string>> nonReleasedPackageKVPs = new List<KeyValuePair<Regex, string>>();
      foreach (var package in projectsUnderDevelopment) {
        nonReleasedPackageKVPs.Add(new KeyValuePair<Regex, string>(
          new Regex(fromPatternP + package.name + fromPatternS),
          toPatternP + package.sourceRelativePath + package.name + "/" + package.name + ".csproj" + toPatternS
        ));

        nonReleasedPackageKVPs.Add(new KeyValuePair<Regex, string>(
          new Regex(fromPatternP + package.name + interfaces + fromPatternS),
          toPatternP + package.sourceRelativePath + package.name + interfaces + "/" + package.name + interfaces +
          ".csproj" +
          toPatternS
        ));
      }
      var nonReleasedPackageReplacementDictionary = new Dictionary<Regex, string>();
      foreach (var kvp in nonReleasedPackageKVPs) {
        nonReleasedPackageReplacementDictionary.Add(kvp.Key, kvp.Value);
      }
      #region GReplacementPatternDictionary for NonReleasedPackages
      var gNonReleasedPackagesPatternReplacement = new GPatternReplacement(gName: "NonReleasedPackages",
        gDictionary: nonReleasedPackageReplacementDictionary);
      #endregion
      #region GReplacementPatternDictionary for SolutionReferencedProjectPaths
      var gSolutionReferencedProjectPathsPatternReplacement = new GPatternReplacement(
        gName: "SolutionReferencedProjectPaths",
        gDictionary: new Dictionary<Regex, string>() {
          {
            new Regex("SolutionReferencedProjectsBasePathReplacementPattern"),
            @"C:/Dropbox/whertzing/GitHub/ATAP.Utilities/"
          },
          {new Regex("SolutionReferencedProjectsLocalBasePathReplacementPattern"), sourceArtifactsPath},
        });
      #endregion
      #endregion

      StringBuilder sb = new StringBuilder(0x2000);
      StringBuilder indent = new StringBuilder(64);
      string indentDelta = "  ";
      string eol = Environment.NewLine;
      CancellationTokenSource cts = new CancellationTokenSource();
      CancellationToken ct = cts.Token;
      var session = new System.Collections.Generic.Dictionary<string, object>();
      R1Top r1Top;
      W1Top w1Top;
      var gAssemblyGroupReplacementPatternDictionary = new Dictionary<Regex, string>();
      gAssemblyGroupReplacementPatternDictionary.AddRange(gNonReleasedPackagesPatternReplacement.GDictionary);
      gAssemblyGroupReplacementPatternDictionary.AddRange(gSolutionReferencedProjectPathsPatternReplacement
        .GDictionary);
      var gAssemblyGroupPatternReplacement = new GPatternReplacement(
        gName: gNonReleasedPackagesPatternReplacement.GName + gSolutionReferencedProjectPathsPatternReplacement.GName,
        gDictionary: gAssemblyGroupReplacementPatternDictionary);


      string assemblyGroupTestArtifactsPath;
      #region executable if present
      GAssemblySingle gPrimaryExecutableAssemblyGroup = gPrimaryExecutingProgram.mCreateAssemblySingleDelegate(gPrimaryExecutingProgram.name,
        gPrimaryExecutingProgram.subDirectoryForGeneratedFiles, gPrimaryExecutingProgram.baseNamespaceName);
      session.Add("assemblyUnits", gPrimaryExecutableAssemblyGroup.GAssemblyUnits);
      r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      w1Top = new W1Top(basePath: gPrimaryExecutingProgram.sourceRelativePath, force: true);
      r1Top.Render(w1Top);
      session.Clear();
      #endregion

      GAssemblyGroup gAssemblyGroup;
      foreach (var projectUnderDevelopment in projectsUnderDevelopment) {
        assemblyGroupTestArtifactsPath = projectUnderDevelopment.testRelativePath;
        gAssemblyGroup = projectUnderDevelopment.mCreateAssemblyGroupDelegate(projectUnderDevelopment.name,
          projectUnderDevelopment.subDirectoryForGeneratedFiles, projectUnderDevelopment.baseNamespaceName);
        #region Update the GPatternReplacement properties for every element of every projectsUnderDevelopment
        MUpdateGPatternReplacement(gAssemblyGroup,gAssemblyGroupPatternReplacement);
        #endregion
        session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
        r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
        w1Top = new W1Top(basePath: projectUnderDevelopment.sourceRelativePath, force: true);
        r1Top.Render(w1Top);
        session.Clear();
      }

      //assemblyGroupName = "ATAP.Utilities.Stateless";
      // assemblyGroupSourceArtifactsPath = Path.Combine(artifactsPath, sourceRelativePath, assemblyGroupName);
      //var gAssemblyGroup = MAUStateless(assemblyGroupName, subDirectoryForGeneratedFiles, "ATAP.Utilities",
      //  gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();

      //string baseNamespaceNameForGHSServices = "ATAP.Utilities.GHS.Services";
      //string genericHostServicesPath = "GenericHostServices";
      //assemblyGroupSourceArtifactsPath = Path.Combine(artifactsPath, sourceRelativePath, genericHostServicesPath);
      //gAssemblyGroup = MTimerGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MFileSystemWatcherGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MConsoleSourceGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gPatternReplacement: gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MConsoleSinkGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gPatternReplacement: gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MConsoleMonitorGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gPatternReplacement: gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MTopLevelBackgroundGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gPatternReplacement: gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();
      //gAssemblyGroup = MFileSystemToObjectGraphGHS(subDirectoryForGeneratedFiles, baseNamespaceNameForGHSServices,
      //  gPatternReplacement: gAssemblyGroupPatternReplacement);
      //session.Add("assemblyUnits", gAssemblyGroup.GAssemblyUnits);
      //r1Top = new R1Top(session, sb, indent, indentDelta, eol, ct);
      //w1Top = new W1Top(basePath: assemblyGroupSourceArtifactsPath, force: true);
      //r1Top.Render(w1Top);
      //session.Clear();

      //  Invoke Editor or Compiler or IDE or Tests on the output files
      //Console.WriteLine(r1Top.Sb);
      //Console.WriteLine("Press any Key to exit");
      //var wait = Console.ReadLine();
    }
  }
}
