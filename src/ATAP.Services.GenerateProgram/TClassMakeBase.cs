using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using System.Security.Permissions;
using System.Xml.Schema;
using ATAP.Utilities.Philote;

namespace GenerateProgram {

  public static partial class GCompilationUnitExtensions {
    public static GCompilationUnit TClassMakeBase(this GCompilationUnit gCompilationUnit, GClass gClass) {
      GClass newGClass;
      string name = gClass.GName + "Base";
      List<GMethod> gMethods = new List<GMethod>();
      foreach (var kvp in gClass.GMethods) {


        var oldGMethod = kvp.Value;
        string newgAccessModifier;
        newgAccessModifier = oldGMethod.GDeclaration.GVisibility == "public" ? "virtual" : "";
        gMethods.Add(new GMethod(new GMethodDeclaration(gName: oldGMethod.GDeclaration.GName,
          gType: oldGMethod.GDeclaration.GType,
          gAccessModifier: newgAccessModifier,
          isStatic: oldGMethod.GDeclaration.IsStatic,
          gArguments: oldGMethod.GDeclaration.GArguments
            )
          , oldGMethod.GBody));
      }
      return gCompilationUnit;
    }


  }
}
