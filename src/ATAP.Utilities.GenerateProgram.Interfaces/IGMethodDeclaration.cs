using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGMethodDeclarationId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGMethodDeclaration<TValue> where TValue : notnull {
    string GName { get; init; }
    string GType { get; init; }
    string GAccessModifier { get; init; }
    bool IsConstructor { get; init; }
    string GVisibility { get; init; }
    bool IsStatic { get; init; }
    IDictionary<IGArgumentId<TValue>, IGArgument<TValue>> GArguments { get; init; }
    string GBase { get; init; }
    string GThis { get; set; }
    bool IsForInterface { get; init; }
    IGMethodDeclarationId<TValue> Id { get; init; }
  }
}



