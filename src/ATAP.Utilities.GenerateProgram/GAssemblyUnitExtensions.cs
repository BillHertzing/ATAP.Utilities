using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.GenerateProgram.GItemGroupInProjectUnitExtensions;
using static ATAP.Utilities.GenerateProgram.Lookup;
using static ATAP.Utilities.GenerateProgram.GMacroExtensions;
using static ATAP.Utilities.GenerateProgram.GClassExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GAssemblyUnitExtensions {

    public static void GAssemblyGroupCommonFinalizer(IGAssemblyGroupBasicConstructorResult gAssemblyGroupBasicConstructorResult) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor,  GCompilationUnit gCompilationUnitDerived
      //var titularBaseClassName = $"{GAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularBaseClassName) ;
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{GAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<IGAssemblyGroup>(){GAssemblyGroup},gClassName:titularClassName) ;
      //#endregion
      #region Create Derived Constructors for all public Base Constructors
      // Create a constructor in the Titular class for every public constructor in the Titular Base class
      var baseConstructorsList = new List<IGMethod>();
      baseConstructorsList.AddRange(gAssemblyGroupBasicConstructorResult.GClassBase.CombinedConstructors());
      foreach (var bc in baseConstructorsList) {
        var gConstructor = new GMethod(new GMethodDeclaration(gAssemblyGroupBasicConstructorResult.GClassDerived.GName, isConstructor: true,
          gVisibility: "public", gArguments: bc.GDeclaration.GArguments, gBase: bc.GDeclaration.GArguments.ToBaseString()));
        gAssemblyGroupBasicConstructorResult.GClassDerived.GMethods.Add(gConstructor.Philote,gConstructor);
      }
      #endregion
      #region Constructor Groups
      // ToDo handle method groups, will require a change to CombinedConstructors
      #endregion
      #region Condense GUsings in the Base and Derived GCompilationUnits of the Titular Assembly
      #endregion
      #region Condense GItemGroups in the GProjectUnit of the Titular Assembly
      #endregion
      #region Finalize the Statemachine
      //(
      //  IEnumerable<GAssemblyUnit> gAssemblyUnits,
      //  IEnumerable<GCompilationUnit> gCompilationUnits,
      //  IEnumerable<GNamespace> gNamespacess,
      //  IEnumerable<GClass> gClasss,
      //  IEnumerable<GMethod> gMethods) lookupResultsTuple = LookupPrimaryConstructorMethod();
      //MStateMachineFinalizer( GClassBase);
      //MStateMachineFinalizer(GTitularBaseCompilationUnit, gNamespace, GClassBase, gConstructorBase, gStateConfigurations);
      //MStateMachineFinalizer(  GClassBase, gConstructorBase, gStateConfigurations);
      MStateMachineFinalizer(gAssemblyGroupBasicConstructorResult);

      #endregion
      #region Populate Interfaces for Titular Derived and Base Class
      PopulateInterface(gAssemblyGroupBasicConstructorResult.GClassDerived, gAssemblyGroupBasicConstructorResult.GTitularInterfaceDerivedInterface);
      PopulateInterface(gAssemblyGroupBasicConstructorResult.GClassBase, gAssemblyGroupBasicConstructorResult.GTitularInterfaceBaseInterface);
      #endregion
      #region populate the Interfaces CompilationUnits for additional classes found in the Titular Derived and Base CompilationUnits
      #endregion
      #region Condense GUsings in the Base and Derived GCompilationUnits of the Titular Interfaces Assembly
      #endregion
      #region Condense GItemGroups in the GProjectUnit of the Titular Interfaces Assembly
      #endregion
    }
  }
}
