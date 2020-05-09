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
    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForConsoleMonitorPattern() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleSink.Interfaces/ConsoleSink.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleSink/ConsoleSink.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleSource.Interfaces/ConsoleSource.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleSource/ConsoleSource.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleMonitor.Interfaces/ConsoleMonitor.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/ConsoleMonitor/ConsoleMonitor.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForConsoleServices",
        "Projects in this solution for the Console Services", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForLoggingUtilities() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.Logging/ATAP.Utilities.Logging.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForLoggingUtilities",
        "Projects in this solution for the Logging Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForReactiveUtilities() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/ATAP.Utilities.Extensions.Reactive/ATAP.Utilities.Extensions.Reactive.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForReactiveUtilities",
        "Projects in this solution for the Reactive Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForPersistenceUtilities() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.Persistence.Interfaces/ATAP.Utilities.Persistence.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/ATAP.Utilities.Extensions.Persistence/ATAP.Utilities.Extensions.Persistence.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternATAP.Utilities.Persistence/ATAP.Utilities.Persistence.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForPersistenceUtilities",
        "Projects in this solution for the Persistence Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForTimersService() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/Timers.Interfaces/Timers.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/Timers/Timers.csproj\" />"
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForTimerService",
        "Projects in this solution for the Timer Service", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForGenericHostUtilities() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/GenericHost/Extensions.GenericHost.Interfaces/Extensions.GenericHost.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/GenericHost/Extensions.GenericHost/Extensions.GenericHost.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForTGenericHostUtilities",
        "Projects in this solution for the GenericHost Utilities", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

 public static GItemGroupInProjectUnit ProjectReferenceItemGroupInProjectUnitForStdInStdOutStdErrServices() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdInSource.Interfaces/StdInSource.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdInSource/StdInSource.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdInMonitor.Interfaces/StdInMonitor.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdInMonitor/StdInMonitor.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdOutSink.Interfaces/StdOutSink.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdOutSink/StdOutSink.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdErrSink.Interfaces/StdErrSink.Interfaces.csproj\" />",
        "<ProjectReference Include=\"SolutionReferencedProjectsBasePathReplacementPatternsrc/services/StdErrSink/StdErrSink.csproj\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ProjectReferencesForStdInStdOutStdErrServices",
        "Projects in this solution for the StdIn, StdOut, and StdErr Services", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }


    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForQuickGraphPackageReferences() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"YC.QuickGraph\" />",
        "<PackageReference Include=\"FSharp.Core\" />",
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("QuickGraphPackageReferences",
        "Packages to persist data to QuickGraph", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForStatelessStatemachinePackageReferences() {
      return new GItemGroupInProjectUnit("StatelessPackageReferences",
        "Packages to for the Stateless lightweight StateMachine library", new List<string>() {
          "<PackageReference Include=\"Stateless\" />",
        });
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForQuickGraphDependentPackageReferences() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"DotNet.Contracts\" />",
        "<PackageReference Include=\"FSharpx.Collections.Experimental\" />"

      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("QuickGraphDependentPackageReferences",
        "Packages to ensure persisting data to QuickGraph uses the correct version of dependent packages", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForReactiveExtensionsPackageReferences() {
      var gItemGroupStatements = new List<string>() {
        "<PackageReference Include=\"System.Reactive\" />"

      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("ReactiveExtensionsPackageReferences",
        "Packages for Reactive Extensions", gItemGroupStatements);
      return gItemGroupInProjectUnit;
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForServiceStackSerializationPackageReferences() {
      return new GItemGroupInProjectUnit("ServiceStackSerializationPackageReferences",
        "ServiceStack Serialization and Dump utility", new List<string>() {
          "<PackageReference Include=\"ServiceStack.Text\" />"
        });
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForServiceStackORMLitePackageReferences() {
      return new GItemGroupInProjectUnit("ServiceStackORMLitePackageReferences",
        "ServiceStack ORMLite (database) utilities", new List<string>() {
          "<PackageReference Include=\"ServiceStack\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite\" />",
          "<PackageReference Include=\"ServiceStack.OrmLite.SqlServer\" />"
        });
    }

    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForNetCoreGenericHostAndWebServerHostPackageReferences() {
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
    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForSerilogLoggingProviderPackageReferences() {
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
    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForSerilogAndSeqMELLoggingProviderPackageReferences() {
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
