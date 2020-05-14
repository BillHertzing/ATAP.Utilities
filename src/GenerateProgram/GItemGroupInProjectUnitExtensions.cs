using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;


namespace GenerateProgram {
  public static partial class GItemGroupInProjectUnitExtensions {

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForEntireService() {
      return  new GItemGroupInProjectUnit("CompleteServiceProjectReferences",
        "Projects in this solution for ", new GBody(new List<string>() {
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/ATAP.Utilities.DataBaseManagement/ATAP.Utilities.DatabaseManagement.csproj\" />",
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/GenerateProgram/GenerateProgram.csproj\" />",
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.Hardware.Extensions/ATAP.Utilities.ComputerInventory.Hardware.Extensions.csproj\" />",
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.ProcessInfo.Models/ATAP.Utilities.ComputerInventory.ProcessInfo.Models.csproj\" />",
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.Software.Enumerations/ATAP.Utilities.ComputerInventory.Software.Enumerations.csproj\" />",
        }));
    }



    public static GItemGroupInProjectUnit ATAPLoggingUtilitiesPackageReferenceItemGroupForProjectUnit() {
      return new GItemGroupInProjectUnit("PackageReferencesForLoggingUtilities",
        "Packages in this solution for the Logging Utilities", new GBody(new List<string>() {
          "<PackageReference Include=\"ATAP.Utilities.Logging\" />",
        }));
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForReactiveUtilities() {
      return new GItemGroupInProjectUnit("ProjectReferencesForReactiveUtilities",
        "Projects in this solution for the Reactive Utilities", new GBody(new List<string>() {
          //$"<ProjectReference Include=\"{basePathToSolution}src/ATAP.Utilities.Extensions.Reactive/ATAP.Utilities.Extensions.Reactive.csproj\" />",
        }));
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(string basePathToSolution) {
      return new GItemGroupInProjectUnit("ProjectReferencesForPersistenceUtilities",
        "Projects in this solution for the Persistence Utilities", new GBody(new List<string>() {
          "<PackageReference Include=\"ATAP.Utilities.Persistence.Interfaces\" />",
          "<PackageReference Include=\"ATAP.Utilities.Extensions.Persistence\" />",
          "<PackageReference Include=\"ATAP.Utilities.Persistence\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}ATAP.Utilities.Persistence.Interfaces/ATAP.Utilities.Persistence.Interfaces.csproj\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}src/ATAP.Utilities.Extensions.Persistence/ATAP.Utilities.Extensions.Persistence.csproj\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}ATAP.Utilities.Persistence/ATAP.Utilities.Persistence.csproj\" />",
        }));
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForTimersService(string basePathToSolution) {
      return new GItemGroupInProjectUnit("ProjectReferencesForTimerService",
        "Projects in this solution for the Timer Service", new GBody(new List<string>() {
          "<PackageReference Include=\"Timers.Interfaces\" />",
          "<PackageReference Include=\"Timers\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}src/services/Timers.Interfaces/Timers.Interfaces.csproj\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}src/services/Timers/Timers.csproj\" />"
        }));
    }

    public static GItemGroupInProjectUnit ATAPGenericHostUtilitiesPackageReferenceItemGroupInProjectUnit(string basePathToSolution) {
      return new GItemGroupInProjectUnit("ProjectReferencesForTGenericHostUtilities",
        "Projects in this solution for the GenericHost Utilities", new GBody(new List<string>() {
          "<PackageReference Include=\"Extensions.GenericHost.Interfaces\" />",
          "<PackageReference Include=\"Extensions.GenericHost\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}src/GenericHost/Extensions.GenericHost.Interfaces/Extensions.GenericHost.Interfaces.csproj\" />",
          //$"<ProjectReference Include=\"{basePathToSolution}src/GenericHost/Extensions.GenericHost/Extensions.GenericHost.csproj\" />",
        }));
    }

    //public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForStdInStdOutStdErrServices(string basePathToSolution) {
    //  var gItemGroupStatements = ;
    //  return new GItemGroupInProjectUnit("ProjectReferencesForStdInStdOutStdErrServices",
    //    "Projects in this solution for the StdIn, StdOut, and StdErr Services", new GBody(new List<string>() {
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInSource.Interfaces/StdInSource.Interfaces.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInSource/StdInSource.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInMonitor.Interfaces/StdInMonitor.Interfaces.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInMonitor/StdInMonitor.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdOutSink.Interfaces/StdOutSink.Interfaces.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdOutSink/StdOutSink.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdErrSink.Interfaces/StdErrSink.Interfaces.csproj\" />",
    //      $"<ProjectReference Include=\"{basePathToSolution}src/services/StdErrSink/StdErrSink.csproj\" />",
    //    }));
    //}

    public static GItemGroupInProjectUnit QuickGraphPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("QuickGraphPackageReferences",
        "Packages to persist data to QuickGraph", new GBody(new List<string>() {
          "<PackageReference Include=\"YC.QuickGraph\" />",
          "<PackageReference Include=\"FSharp.Core\" />",
        }));
    }

    public static GItemGroupInProjectUnit StatelessStateMachinePackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("StatelessPackageReferences",
        "Packages to for the Stateless lightweight StateMachine library", new GBody(new List<string>() {
          "<PackageReference Include=\"Stateless\" />",
        }));
    }

    public static GItemGroupInProjectUnit QuickGraphDependentPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("QuickGraphDependentPackageReferences",
        "Packages to ensure persisting data to QuickGraph uses the correct version of dependent packages", new GBody(new List<string>() {
          "<PackageReference Include=\"DotNet.Contracts\" />",
          "<PackageReference Include=\"FSharpx.Collections.Experimental\" />"
        }));
    }

    public static GItemGroupInProjectUnit ReactiveExtensionsPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ReactiveExtensionsPackageReferences",
        "Packages for Reactive Extensions", new GBody(new List<string>() {
          "<PackageReference Include=\"System.Reactive\" />"
        }));
    }

    public static GItemGroupInProjectUnit ServiceStackSerializationPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ServiceStackSerializationPackageReferences",
        "ServiceStack Serialization and Dump utility", new GBody(new List<string>() {
          "<PackageReference Include=\"ServiceStack.Text\" />"
        }));
    }

    public static GItemGroupInProjectUnit ServiceStackORMLitePackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ServiceStackORMLitePackageReferences",
        "ServiceStack ORMLite (database) utilities", new GBody(new List<string>() {
          "<PackageReference Include=\"ServiceStack\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite.SqlServer\" />"
        }));
    }

    public static GItemGroupInProjectUnit NetCoreGenericHostPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("NetCoreGenericHostAndWebServerHostPackageReferences",
        "Packages necessary to run the ASP.Net Core Generic Host and web server hosts Server", new GBody(new List<string>() {
          "<PackageReference Include=\"Microsoft.Extensions.Configuration\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.CommandLine\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.EnvironmentVariables\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.Json\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Hosting\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Localization\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Logging\" />",
        }));
    }
    public static GItemGroupInProjectUnit SerilogLoggingProviderPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("SerilogLoggingProviderPackageReferences",
        "Packages to implement Serilog as logging provider", new GBody(new List<string>() {
          "<PackageReference Include=\"Serilog\" />",
          "<PackageReference Include=\"Serilog.Settings.Configuration\" />",
          "<PackageReference Include=\"Serilog.Enrichers.Thread\" />",
          "<PackageReference Include=\"Serilog.Exceptions\" />",
          "<PackageReference Include=\"Serilog.Extensions.Hosting\" />",
          "<PackageReference Include=\"Serilog.Sinks.Console\" />",
          "<PackageReference Include=\"Serilog.Sinks.Debug\" />",
          "<PackageReference Include=\"Serilog.Sinks.File\" />",
          "<PackageReference Include=\"Serilog.Sinks.Seq\" />",
          "<PackageReference Include=\"SerilogAnalyzer\" />"
        }));
    }
    public static GItemGroupInProjectUnit SerilogAndSeqMELLoggingProviderPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("SerilogAndSeqMELLoggingProviderPackageReferences",
        "Packages to add Serilog and SEQ as Microsoft.Extensions.Logging providers", new GBody(new List<string>() {
          "<PackageReference Include=\"Serilog.Extensions.Logging\" />",
          "<PackageReference Include=\"Seq.Extensions.Logging\" />",
        }));
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences() {
      return new GItemGroupInProjectUnit("ILWeavingUsingFodyPackageReferences",
        "Packages to implement IL Weaving using Fody during the build process", new GBody(new List<string>() {
          "<PackageReference Include=\"MethodBoundaryAspect.Fody\" Version=\"2.0.118\" />",
          "<PackageReference Include=\"ATAP.Utilities.ETW\" />",
          "<!-- <ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPattern\\src\\ATAP.Utilities.ETW\\ATAP.Utilities.ETW.csproj\" /> -->",
        }));
    }



  }
}
