using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;
using static GenerateProgram.GCompilationUnitExtensions;
using static GenerateProgram.GClassExtensions;
using static GenerateProgram.GItemGroupInProjectUnitExtensions;
using static GenerateProgram.GPropertyGroupInProjectUnitExtensions;
using static GenerateProgram.StringConstants;
//using AutoMapper.Configuration;
using static GenerateProgram.GMethodGroupExtensions;
using static GenerateProgram.GMethodExtensions;
using static GenerateProgram.GUsingGroupExtensions;
using static GenerateProgram.GMacroExtensions;
using static GenerateProgram.GArgumentExtensions;
using static GenerateProgram.Lookup;

namespace GenerateProgram {
  public static partial class GMacroExtensions {
    //public static void MAssemblyGroupPopulateBaseInterfaces(GAssemblyGroup gAssemblyGroup = default,
    //  ) {
    //  if (gAssemblyGroup == default) {throw new ArgumentException(nameof(gAssemblyGroup));};

    //  /**************************************************************************************************/
    //  var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
    //  var titularBaseInterfaceName = $"I{gAssemblyGroup.GName}Base";
    //  var titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
    //  var titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<GAssemblyGroup>(){gAssemblyGroup},gInterfaceName:titularBaseInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());
      
    //  var titularClassName = $"{gAssemblyGroup.GName}";
    //  var titularInterfaceName = $"I{gAssemblyGroup.GName}";
    //  titularAssemblyUnitLookupResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
    //  titularInterfaceAssemblyUnitLookupResults = LookupInterfaces(new List<GAssemblyGroup>(){gAssemblyGroup},gInterfaceName:titularInterfaceName);
    //  PopulateInterface(titularAssemblyUnitLookupResults.gClasss.First(),
    //    titularInterfaceAssemblyUnitLookupResults.gInterfaces.First());
    //}
    //public static void MAssemblyGroupPopulateTitularInterfaces(GAssemblyGroup gAssemblyGroup = default
    //) {
    //  if (gAssemblyGroup == default) {throw new ArgumentException(nameof(gAssemblyGroup));};

    //}

  }
}
