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

    public static void GAssemblyGroupCommonFinalizer(GAssemblyGroupBasicConstructorResult gAssemblyGroupBasicConstructorResult) {
      //#region Lookup the Base GAssemblyUnit, GCompilationUnit, GNamespace, GClass, and primary GConstructor,  GCompilationUnit gCompilationUnitDerived
      //var titularBaseClassName = $"{gAssemblyGroup.GName}Base";
      //var titularAssemblyUnitLookupPrimaryConstructorResults = LookupPrimaryConstructorMethod(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularBaseClassName) ;
      //#endregion
      //#region Lookup the Derived GAssemblyUnit, GCompilationUnit, GNamespace, and GClass
      //var titularClassName = $"{gAssemblyGroup.GName}";
      //var titularAssemblyUnitLookupDerivedClassResults = LookupDerivedClass(new List<GAssemblyGroup>(){gAssemblyGroup},gClassName:titularClassName) ;
      //#endregion
      #region Create Derived Constructors for all public Base Constructors
      // Create a constructor in the Titular class for every public constructor in the Titular Base class
      var baseConstructorsList = new List<GMethod>();
      baseConstructorsList.AddRange(gAssemblyGroupBasicConstructorResult.gClassBase.CombinedConstructors());
      foreach (var bc in baseConstructorsList) {
        var gConstructor = new GMethod(new GMethodDeclaration(gAssemblyGroupBasicConstructorResult.gClassDerived.GName, isConstructor: true,
          gVisibility: "public", gArguments: bc.GDeclaration.GArguments, gBase: bc.GDeclaration.GArguments.ToBaseString()));
        gAssemblyGroupBasicConstructorResult.gClassDerived.GMethods.Add(gConstructor.Philote,gConstructor);
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
      //MStateMachineFinalizer( gClassBase);
      //MStateMachineFinalizer(gTitularBaseCompilationUnit, gNamespace, gClassBase, gConstructorBase, gStateConfigurations);
      //MStateMachineFinalizer(  gClassBase, gConstructorBase, gStateConfigurations);
      MStateMachineFinalizer(gAssemblyGroupBasicConstructorResult);

      #endregion
      #region Populate Interfaces for Titular Derived and Base Class
      PopulateInterface(gAssemblyGroupBasicConstructorResult.gClassDerived, gAssemblyGroupBasicConstructorResult.gTitularInterfaceDerivedInterface);
      PopulateInterface(gAssemblyGroupBasicConstructorResult.gClassBase, gAssemblyGroupBasicConstructorResult.gTitularInterfaceBaseInterface);
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
