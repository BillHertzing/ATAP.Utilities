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
    //public static void MAssemblyGroupPopulateBaseInterfaces(GAssemblyGroup gAssemblyGroup = default,
    //  ) {
    //  if (gAssemblyGroup == default) {throw new ArgumentException(nameof(gAssemblyGroup));};

    //  /**************************************************************************************************/
    //  var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
    //  var titularBaseInterfaceName = $"I{gAssemblyGroup.GName}Base";
    //  var titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
    //  var titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<IGAssemblyGroup>(){gAssemblyGroup},gInterfaceName:titularBaseInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());
      
    //  var titularClassName = $"{gAssemblyGroup.GName}";
    //  var titularInterfaceName = $"I{gAssemblyGroup.GName}";
    //  titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
    //  titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<IGAssemblyGroup>(){gAssemblyGroup},gInterfaceName:titularInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());
    //}
    //public static void MAssemblyGroupPopulateTitularInterfaces(GAssemblyGroup gAssemblyGroup = default
    //) {
    //  if (gAssemblyGroup == default) {throw new ArgumentException(nameof(gAssemblyGroup));};

    //}

  }
}
