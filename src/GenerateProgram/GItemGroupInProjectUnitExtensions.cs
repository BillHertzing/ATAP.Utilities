using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using GenerateProgram;

namespace GenerateProgram {
  public static partial class GItemGroupInProjectUnitExtensions {
    public static GItemGroupInProjectUnit ItemGroupInProjectUnitForEntireService() {
      var gItemGroupStatements = new List<string>() {
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.Logging\\ATAP.Utilities.Logging.csproj\" />",
        "<ProjectReference Include=\"..\\ATAP.Utilities.DataBaseManagement\\ATAP.Utilities.DatabaseManagement.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.ComputerInventory.Hardware.Extensions\\ATAP.Utilities.ComputerInventory.Hardware.Extensions.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.ComputerInventory.ProcessInfo.Models\\ATAP.Utilities.ComputerInventory.ProcessInfo.Models.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.ComputerInventory.Software.Enumerations\\ATAP.Utilities.ComputerInventory.Software.Enumerations.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.Logging\\ATAP.Utilities.Logging.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.Persistence.Interfaces\\ATAP.Utilities.Persistence.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\..\\ATAP.Utilities.Persistence\\ATAP.Utilities.Persistence.csproj\" />",
        "<ProjectReference Include=\"..\\ATAP.Utilities.AConsole01.StringConstants\\ATAP.Utilities.AConsole01.StringConstants.csproj\" />",
        "<ProjectReference Include=\"..\\ATAP.Utilities.Extensions.Persistence\\ATAP.Utilities.Extensions.Persistence.csproj\" />",
        "<ProjectReference Include=\"..\\ATAP.Utilities.Extensions.Reactive\\ATAP.Utilities.Extensions.Reactive.csproj\" />",
        "<ProjectReference Include=\"..\\GenericHost\\Extensions.GenericHost.Interfaces\\Extensions.GenericHost.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\GenericHost\\Extensions.GenericHost\\Extensions.GenericHost.csproj\" />",
        "<ProjectReference Include=\"..\\services\\GenerateProgram\\GenerateProgram.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleSink.Interfaces\\ConsoleSink.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleSink\\ConsoleSink.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleSource.Interfaces\\ConsoleSource.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleSource\\ConsoleSource.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleMonitor.Interfaces\\ConsoleMonitor.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\services\\ConsoleMonitor\\ConsoleMonitor.csproj\" />",
        "<ProjectReference Include=\"..\\services\\Timers.Interfaces\\Timers.Interfaces.csproj\" />",
        "<ProjectReference Include=\"..\\services\\Timers\\Timers.csproj\" />"
      };
      var gItemGroupInProjectUnit = new GItemGroupInProjectUnit("CompleteServiceProjectReferences",
        "Projects in this solution for completecurentservice", gItemGroupStatements);
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
          "<ProjectReference Include=\"..\\ATAP.Utilities.ETW\\ATAP.Utilities.ETW.csproj\" />",
        });
    }

  }
}
