using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GMethodDeclaration : IGMethodDeclaration {
    public GMethodDeclaration(string gName = default, string gType = default, string gVisibility = default, string gAccessModifier = default,
      bool isStatic = default, bool isConstructor = default,
      Dictionary<IPhilote<IGArgument>, IGArgument> gArguments = default,
      string gBase = default, string gThis = default, bool isForInterface = false) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;
      GType = gType == default ? "" : gType;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      IsStatic = isStatic == default ? false : (bool)isStatic;
      IsConstructor = isConstructor == default ? false : (bool)isConstructor;
      GArguments = gArguments == default ? new Dictionary<Philote<GArgument>, GArgument>() : gArguments;
      GBase = gBase == default ? "" : gBase;
      GThis = gThis == default ? "" : gThis;
      IsForInterface = isForInterface;
      Philote = new Philote<GMethodDeclaration>();
    }
    public string GName { get; init; }
    public string GType { get; init; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public bool IsConstructor { get; init; }
    public string GVisibility { get; init; }
    public bool IsStatic { get; init; }
    public Dictionary<IPhilote<IGArgument>, IGArgument> GArguments { get; init; }
    public string GBase { get; init; }
    public string GThis { get; set; }
    public bool IsForInterface { get; init; }
    public IPhilote<IGMethodDeclaration> Philote { get; init; }

  }
}
