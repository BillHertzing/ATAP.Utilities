using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Collection;
using ATAP.Utilities.Philote;
using static GenerateProgram.GAssemblyUnitExtensions;
using static GenerateProgram.GCompilationUnitExtensions;
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
    public static GAssemblyGroupBasicConstructorResult MAssemblyGroupCommonConstructorForServicesAndConsolePrograms(
      string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      GPatternReplacement gPatternReplacement = default) {
      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupBasicConstructor(gAssemblyGroupName,
        subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, gPatternReplacement);
      #region Upate the ProjectUnit
      #region PropertyGroups 
      new List<GPropertyGroupInProjectUnit>() {
        PropertyGroupInProjectUnitForProjectUnitIsExecutable(),
        PropertyGroupInProjectUnitForPackableOnBuild(),
        PropertyGroupInProjectUnitForLifecycleStage(),
        PropertyGroupInProjectUnitForBuildConfigurations(),
        PropertyGroupInProjectUnitForVersionInfo()
      }.ForEach(gP => {
        gAssemblyGroupBasicConstructorResult.gTitularAssemblyUnit.GProjectUnit.GPropertyGroupInProjectUnits.Add(gP.Philote, gP);
      });
      #endregion
      #region PropertyGroups only in Titular AssemblyUnit
      new List<GItemGroupInProjectUnit>() {
        //TBD
      }.ForEach(o => {
        gAssemblyGroupBasicConstructorResult.gTitularAssemblyUnit.GProjectUnit.GItemGroupInProjectUnits.Add(o.Philote, o);
      });
      #endregion
      #endregion

        MAssemblyGroupStringConstants(gAssemblyGroupBasicConstructorResult);
      return gAssemblyGroupBasicConstructorResult;
    }
  }
}
