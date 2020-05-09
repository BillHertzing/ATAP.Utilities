using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GConstructorDeclaration : GMethodDeclaration {
    public GConstructorDeclaration(string gName = default, string gType = default, string gVisibility = default,string gAccessModifier = default,
      bool isStatic = default, bool isConstructor = default,
      Dictionary<Philote<GArgument>, GArgument> gArguments = default, string gBase = default, string gThis = default) :
      base(gName, gType, gVisibility, gAccessModifier,isStatic, isConstructor, gArguments, gBase, gThis) {
      Philote = new Philote<GConstructorDeclaration>();
    }

    public GConstructorDeclaration(
      Dictionary<Philote<GArgument>, GArgument> gArguments) : this(gVisibility: "", gArguments: gArguments) {
    }


    public new Philote<GConstructorDeclaration> Philote { get; }

  }
}
