using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GCompilationUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GClassExtensions;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static ATAP.Utilities.GenerateProgram.GMethodGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMethodExtensions;
using static ATAP.Utilities.GenerateProgram.GUsingGroupExtensions;
using static ATAP.Utilities.GenerateProgram.GMacroExtensions;
using static ATAP.Utilities.GenerateProgram.GArgumentExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GMacroExtensions {
    //public static void MAssemblyGroupPopulateBaseInterfaces(GAssemblyGroup GAssemblyGroup = default,
    //  ) {
    //  if (GAssemblyGroup == default) {throw new ArgumentException(nameof(GAssemblyGroup));};

    //  /**************************************************************************************************/
    //  var titularBaseClassName = $"{GAssemblyGroup.GName}Base";
    //  var titularBaseInterfaceName = $"I{GAssemblyGroup.GName}Base";
    //  var titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularBaseClassName) ;
    //  var titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<IGAssemblyGroup>(){GAssemblyGroup},gInterfaceName:titularBaseInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());

    //  var titularClassName = $"{GAssemblyGroup.GName}";
    //  var titularInterfaceName = $"I{GAssemblyGroup.GName}";
    //  titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularClassName) ;
    //  titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<IGAssemblyGroup>(){GAssemblyGroup},gInterfaceName:titularInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());
    //}
    //public static void MAssemblyGroupPopulateTitularInterfaces(GAssemblyGroup GAssemblyGroup = default
    //) {
    //  if (GAssemblyGroup == default) {throw new ArgumentException(nameof(GAssemblyGroup));};

    //}

  }
}
