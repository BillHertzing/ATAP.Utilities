using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGMethodDeclaration {
    string GName { get; init; }
    string GType { get; init; }
    string GAccessModifier { get; init; }
    bool IsConstructor { get; init; }
    string GVisibility { get; init; }
    bool IsStatic { get; init; }
    IDictionary<IPhilote<IGArgument>, IGArgument> GArguments { get; init; }
    string GBase { get; init; }
    string GThis { get; set; }
    bool IsForInterface { get; init; }
    IPhilote<IGMethodDeclaration> Philote { get; init; }
  }
}
