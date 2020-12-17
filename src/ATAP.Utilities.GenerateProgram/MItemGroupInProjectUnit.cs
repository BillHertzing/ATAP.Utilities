using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {

    public static IList<IGItemGroupInProjectUnit> MGenericHostServiceCommonItemGroupInProjectUnitList() {
      return new List<IGItemGroupInProjectUnit>() {
        NetCoreGenericHostReferencesItemGroupInProjectUnit(),
        MStatelessStateMachineReferencesItemGroupInProjectUnit(),
        ATAPLoggingUtilitiesReferencesItemGroupInProjectUnit(),
        MFodyMethodBoundryReferencesItemGroupInProjectUnit(),
      };
    }

    public static IGItemGroupInProjectUnit MStatelessStateMachineReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("StatelessPackageReferences",
        "Packages for the Stateless lightweight StateMachine library", new GBody(new List<string>() {
          "<PackageReference Include=\"Stateless\" />",
          "<PackageReference Include=\"ATAP.Utilities.Stateless\" />",
        }));
    }

    public static IGItemGroupInProjectUnit MFodyMethodBoundryReferencesItemGroupInProjectUnit() {
      return new GItemGroupInProjectUnit("ILWeavingUsingFodyPackageReferences",
        "Packages to implement ETW logging of Method Boundaries by using Fody for IL Weaving during the build process", new GBody(new List<string>() {
          "<PackageReference Include=\"MethodBoundaryAspect.Fody\" />",
          "<PackageReference Include=\"ATAP.Utilities.ETW\" />",
        }));
    }
  }
}
