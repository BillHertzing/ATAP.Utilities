using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;

namespace GenerateProgram {
  public static partial class GMacroExtensions {

    public static List<GItemGroupInProjectUnit> MGenericHostServiceCommonItemGroupInProjectUnitList() {
      return new List<GItemGroupInProjectUnit>() {
        NetCoreGenericHostReferencesItemGroupInProjectUnit(),
        MStatelessStateMachineReferencesItemGroupInProjectUnit(),
        ATAPLoggingUtilitiesReferencesItemGroupInProjectUnit(),
        MFodyMethodBoundryReferencesItemGroupInProjectUnit(),
      };
    }

    public static GItemGroupInProjectUnit MStatelessStateMachineReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("StatelessPackageReferences",
        "Packages for the Stateless lightweight StateMachine library", new GBody(new List<string>() {
          "<PackageReference Include=\"Stateless\" />",
        }));
    }

    public static GItemGroupInProjectUnit MFodyMethodBoundryReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ILWeavingUsingFodyPackageReferences",
        "Packages to implement IL Weaving using Fody during the build process", new GBody(new List<string>() {
          "<PackageReference Include=\"MethodBoundaryAspect.Fody\" Version=\"2.0.118\" />",
          "<PackageReference Include=\"ATAP.Utilities.ETW\" />",
        }));
    }
  }
}
