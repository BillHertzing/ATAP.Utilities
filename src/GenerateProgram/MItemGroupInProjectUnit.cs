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
        NetCoreGenericHostPackageReferencesItemGroupInProjectUnit(),
        StatelessStateMachinePackageReferencesItemGroupInProjectUnit(),
        ATAPLoggingUtilitiesPackageReferenceItemGroupForProjectUnit(),
        ItemGroupInProjectUnitForILWeavingUsingFodyPackageReferences(),
      };
    }
  }
}
