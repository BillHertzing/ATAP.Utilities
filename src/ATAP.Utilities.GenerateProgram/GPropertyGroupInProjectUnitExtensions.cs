using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;


namespace ATAP.Utilities.GenerateProgram {
  public static partial class GPropertyGroupInProjectUnitExtensions {
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForPackableLibraryVersionedConfigurations() {
      return new GPropertyGroupInProjectUnit("PackableProductionV1.0.0Library", "what kind of an assembly",
        new List<string>() {
          "<OutputType>Library</OutputType>",
          "<GeneratePackageOnBuild>true</GeneratePackageOnBuild>",
          "<IsPackable>true</IsPackable>",
          "<!-- Assembly, File, and Package Information for this assembly-->",
          "<!-- Build and revision are created based on date-->",
          "<MajorVersion>1</MajorVersion>",
          "<MinorVersion>0</MinorVersion>",
          "<PatchVersion>0</PatchVersion>",
          "<!-- Current Lifecycle stage for this assembly -->",
          "<PackageLifeCycleStage>Production</PackageLifeCycleStage>",
          "<!-- NuGet Package Label for the Nuget Package if the LifecycleStage is not Production-->",
          "<!-- However, if the LifecycleStage is Production, the NuGet Package Label is ignored, but MSBuild expects a non-null value  -->",
          "<PackageLabel>NA</PackageLabel>",
          "<Configurations>Debug;Release;ReleaseWithTrace</Configurations>",
        });
    }

    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForProjectUnitIsExecutable() {
      return new GPropertyGroupInProjectUnit("Executable", "Creates a Executable Project", new List<string>() {
        "<OutputType>Exe</OutputType>"
      });
    }

    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForProjectUnitIsLibrary() {
      return new GPropertyGroupInProjectUnit("Library", "Creates a Library Project", new List<string>() {
        "<OutputType>Library</OutputType>"
      });
    }

    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForProjectUnitIsExe() {
      return new GPropertyGroupInProjectUnit("Executable", "Creates an Executable Project", new List<string>() {
        "<OutputType>Exe</OutputType>"
      });
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForPackableOnBuild() {
      return new GPropertyGroupInProjectUnit("PackableOnBuild", "The Assembly will be packed into a NuGet Package on every build", new List<string>() {
        "<GeneratePackageOnBuild>true</GeneratePackageOnBuild>",
        "<IsPackable>true</IsPackable>",
      });
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForLifecycleStage() {
      return new GPropertyGroupInProjectUnit("LifecycleStage", "Describes the current stage in the development/Release lifecycle for this Assembly", new List<string>() {
        "<!-- Current Lifecycle stage for this assembly -->",
        "<PackageLifeCycleStage>Production</PackageLifeCycleStage>",
        "<!-- NuGet Package Label for the Nuget Package if the LifecycleStage is not Production-->",
        "<!-- However, if the LifecycleStage is Production, the NuGet Package Label is ignored, but MSBuild expects a non-null value  -->",
        "<PackageLabel>NA</PackageLabel>",
      });
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForBuildConfigurations() {
      return new GPropertyGroupInProjectUnit("BuildConfigurations", "The BuildConfigurations available for this assembly", new List<string>() {
        "<Configurations>Debug;Release;ReleaseWithTrace</Configurations>",
      });
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForVersionInfo(Version version) {
      return new GPropertyGroupInProjectUnit("Version", "The current version of this assembly", new List<string>() {
        "<!-- Assembly, File, and Package Information for this assembly-->",
        "<!-- Build and revision are created based on date-->",
        $"<MajorVersion>{version.Major}</MajorVersion>",
        $"<MinorVersion>{version.Minor}</MinorVersion>",
        $"<PatchVersion>{version.Revision}</PatchVersion>",
      });
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitForVersionInfo() {
      return PropertyGroupInProjectUnitForVersionInfo(new Version());
    }
    public static GPropertyGroupInProjectUnit PropertyGroupInProjectUnitFor() {
      return new GPropertyGroupInProjectUnit("", "", new List<string>() {
      });
    }
  }

}
