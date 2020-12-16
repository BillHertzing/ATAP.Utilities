using System;
using System.Collections.Generic;
//using System.Management.Instrumentation;
using ATAP.Utilities.Philote;


namespace ATAP.Utilities.GenerateProgram {
  public class GMethodDeclaration {
    public GMethodDeclaration(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      bool isStatic = default,bool isConstructor = default,
      Dictionary<Philote<GArgument>, GArgument> gArguments = default,
      string gBase = default, string gThis = default, bool isForInterface = false) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      IsStatic = isStatic == default ? false : (bool) isStatic;
      IsConstructor = isConstructor == default ? false : (bool) isConstructor;
      GArguments = gArguments == default ? new Dictionary<Philote<GArgument>, GArgument>() : gArguments;
      GBase = gBase == default ? "" : gBase;
      GThis = gThis == default ? "" : gThis;
      IsForInterface = isForInterface;
      Philote = new Philote<GMethodDeclaration>();
    }
    public string GName { get; }
    public string GType { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public bool IsConstructor { get; }
    public string GVisibility { get; }
    public bool IsStatic { get; }
    public Dictionary<Philote<GArgument>, GArgument> GArguments { get; }
    public string GBase { get; }
    public string GThis { get; set; }
    public bool IsForInterface { get; }
    public Philote<GMethodDeclaration> Philote { get; }

  }
}
