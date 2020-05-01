using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GConstructorDeclaration : GMethodDeclaration {
    public GConstructorDeclaration(string gName = default, string gType = default, string gVisibility = default,string? gAccessModifier = default, bool isStatic = default, bool isConstructor = default,
      Dictionary<Philote<GMethodArgument>, GMethodArgument>? gMethodArguments = default, string? gBase = default, string? gThis = default) : base(gName, gType, gVisibility, gAccessModifier,isStatic, isConstructor, gMethodArguments, gBase, gThis) {
      Philote = new Philote<GConstructorDeclaration>();
    }

    public GConstructorDeclaration(
      Dictionary<Philote<GMethodArgument>, GMethodArgument>? gMethodArguments) : this(gVisibility: "", gMethodArguments: gMethodArguments) {
    }


    public new Philote<GConstructorDeclaration> Philote { get; }

  }
}
