using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Xml.Schema;
using ATAP.Utilities.Collection;
using ATAP.Utilities.Philote;
using static ATAP.Utilities.GenerateProgram.GAssemblyUnitExtensions;
using static ATAP.Utilities.GenerateProgram.GCompilationUnitExtensions;
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
    public static IGAssemblyGroupBasicConstructorResult MAssemblyGroupCommonConstructorForServicesAndConsolePrograms(
      string gAssemblyGroupName = default,
      string subDirectoryForGeneratedFiles = default, string baseNamespaceName = default, bool hasInterfaces = true,
      IGPatternReplacement gPatternReplacement = default) {
      var gAssemblyGroupBasicConstructorResult = MAssemblyGroupBasicConstructor(gAssemblyGroupName,
        subDirectoryForGeneratedFiles, baseNamespaceName, hasInterfaces, gPatternReplacement);
      #region Upate the ProjectUnit
      #region PropertyGroups 
      new List<IGPropertyGroupInProjectUnit>() {
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
      new List<IGItemGroupInProjectUnit>() {
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
