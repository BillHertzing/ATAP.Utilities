using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GMethodDeclaration {
    public GMethodDeclaration(string? gName = default, string? gType = default, string? gVisibility = default, bool? isStatic = default,bool? isConstructor = default, Dictionary<Philote<GMethodArgument>, GMethodArgument>? gMethodArguments = default, string? gBase = default, string? gThis = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      IsStatic = isStatic == default ? false : (bool) isStatic;
      IsConstructor = isConstructor == default ? false : (bool) isConstructor;
      GMethodArguments = gMethodArguments == default ? new Dictionary<Philote<GMethodArgument>, GMethodArgument>() : gMethodArguments;

      if (gBase == default) {
        GBase = "";
      }
      else {
        GBase = gBase;
      }
      if (gThis == default) {
        GThis = "";
      }
      else {
        GThis = gThis;
      }
      Philote = new Philote<GMethodDeclaration>();
    }
    public string GName { get; }
    public string? GType { get; }
    public bool? IsConstructor { get; }
    public string? GVisibility { get; }
    public bool? IsStatic { get; }
    public Dictionary<Philote<GMethodArgument>, GMethodArgument>? GMethodArguments { get; }
    public string GBase { get; }
    public string GThis { get; set; }
    public Philote<GMethodDeclaration> Philote { get; }

  }
}
