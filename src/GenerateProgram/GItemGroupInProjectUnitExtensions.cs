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
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/ATAP.Utilities.DataBaseManagement/ATAP.Utilities.DatabaseManagement.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/GenerateProgram/GenerateProgram.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.Hardware.Extensions/ATAP.Utilities.ComputerInventory.Hardware.Extensions.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.ProcessInfo.Models/ATAP.Utilities.ComputerInventory.ProcessInfo.Models.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.ComputerInventory.Software.Enumerations/ATAP.Utilities.ComputerInventory.Software.Enumerations.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("CompleteServiceProjectReferences",
        "Projects in this solution for ", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }
    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForConsoleMonitorPattern(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleSink.Interfaces/ConsoleSink.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleSink/ConsoleSink.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleSource.Interfaces/ConsoleSource.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleSource/ConsoleSource.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleMonitor.Interfaces/ConsoleMonitor.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ConsoleMonitor/ConsoleMonitor.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForConsoleServices",
        "Projects in this solution for the Console Services", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForLoggingUtilities(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}ATAP.Utilities.Logging/ATAP.Utilities.Logging.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForLoggingUtilities",
        "Projects in this solution for the Logging Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForReactiveUtilities(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}src/ATAP.Utilities.Extensions.Reactive/ATAP.Utilities.Extensions.Reactive.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForReactiveUtilities",
        "Projects in this solution for the Reactive Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}ATAP.Utilities.Persistence.Interfaces/ATAP.Utilities.Persistence.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/ATAP.Utilities.Extensions.Persistence/ATAP.Utilities.Extensions.Persistence.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}ATAP.Utilities.Persistence/ATAP.Utilities.Persistence.csproj\" />",
      };
      return new GItemGroupInProjectUnit("ProjectReferencesForPersistenceUtilities",
        "Projects in this solution for the Persistence Utilities", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForTimersService(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}src/services/Timers.Interfaces/Timers.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/Timers/Timers.csproj\" />"
      };
      return new GItemGroupInProjectUnit("ProjectReferencesForTimerService",
        "Projects in this solution for the Timer Service", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}src/GenericHost/Extensions.GenericHost.Interfaces/Extensions.GenericHost.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/GenericHost/Extensions.GenericHost/Extensions.GenericHost.csproj\" />",
      };
      return new GItemGroupInProjectUnit("ProjectReferencesForTGenericHostUtilities",
        "Projects in this solution for the GenericHost Utilities", gItemGroupStatements);
    }

 public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForStdInStdOutStdErrServices(string basePathToSolution) {
      var gItemGroupStatements = new List<string>() {
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInSource.Interfaces/StdInSource.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInSource/StdInSource.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInMonitor.Interfaces/StdInMonitor.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdInMonitor/StdInMonitor.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdOutSink.Interfaces/StdOutSink.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdOutSink/StdOutSink.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdErrSink.Interfaces/StdErrSink.Interfaces.csproj\" />",
        $"<ProjectReference Include=\"{basePathToSolution}src/services/StdErrSink/StdErrSink.csproj\" />",
      };
      return new GItemGroupInProjectUnit("ProjectReferencesForStdInStdOutStdErrServices",
        "Projects in this solution for the StdIn, StdOut, and StdErr Services", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit QuickGraphPackageReferencesItemGroupInProjectUnit() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"YC.QuickGraph\" />",
        "<PackageReference Include=\"FSharp.Core\" />",
      };
      return new GItemGroupInProjectUnit("QuickGraphPackageReferences",
        "Packages to persist data to QuickGraph", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit StatelessStateMachinePackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("StatelessPackageReferences",
        "Packages to for the Stateless lightweight StateMachine library", new List<string>() {
          "<PackageReference Include=\"Stateless\" />",
        });
    }

    public static GItemGroupInProjectUnit QuickGraphDependentPackageReferencesItemGroupInProjectUnit() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"DotNet.Contracts\" />",
        "<PackageReference Include=\"FSharpx.Collections.Experimental\" />"

      };
      return new GItemGroupInProjectUnit("QuickGraphDependentPackageReferences",
        "Packages to ensure persisting data to QuickGraph uses the correct version of dependent packages", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit ReactiveExtensionsPackageReferencesItemGroupInProjectUnit() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"System.Reactive\" />"

      };
      return new GItemGroupInProjectUnit("ReactiveExtensionsPackageReferences",
        "Packages for Reactive Extensions", gItemGroupStatements);
    }

    public static GItemGroupInProjectUnit ServiceStackSerializationPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ServiceStackSerializationPackageReferences",
        "ServiceStack Serialization and Dump utility", new List<string>() {
          "<PackageReference Include=\"ServiceStack.Text\" />"
        });
    }

    public static GItemGroupInProjectUnit ServiceStackORMLitePackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ServiceStackORMLitePackageReferences",
        "ServiceStack ORMLite (database) utilities", new List<string>() {
          "<PackageReference Include=\"ServiceStack\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite.SqlServer\" />"
        });
    }

    public static GItemGroupInProjectUnit NetCoreGenericHostAndWebServerHostPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("NetCoreGenericHostAndWebServerHostPackageReferences",
        "Packages necessary to run the ASP.Net Core Generic Host and web server hosts Server", new List<string>() {
          "<PackageReference Include=\"Microsoft.Extensions.Configuration\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.CommandLine\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.EnvironmentVariables\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Configuration.Json\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Hosting\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Localization\" />",
          "<PackageReference Include=\"Microsoft.Extensions.Logging\" />",
        });
    }
    public static GItemGroupInProjectUnit SerilogLoggingProviderPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("SerilogLoggingProviderPackageReferences",
        "Packages to implement Serilog as logging provider", new List<string>() {
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
        });
    }
    public static GItemGroupInProjectUnit SerilogAndSeqMELLoggingProviderPackageReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("SerilogAndSeqMELLoggingProviderPackageReferences",
        "Packages to add Serilog and SEQ as Microsoft.Extensions.Logging providers", new List<string>() {
          "<PackageReference Include=\"Serilog.Extensions.Logging\" />",
          "<PackageReference Include=\"Seq.Extensions.Logging\" />",
        });
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences() {
      return new GItemGroupInProjectUnit("ILWeavingUsingFodyPackageReferences",
        "Packages and projects to implement IL Weaving using Fody during the build process", new List<string>() {
          "<PackageReference Include=\"MethodBoundaryAspect.Fody\" Version=\"2.0.118\" />",
          "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPattern\\src\\ATAP.Utilities.ETW\\ATAP.Utilities.ETW.csproj\" />",
        });
    }

  }
}
