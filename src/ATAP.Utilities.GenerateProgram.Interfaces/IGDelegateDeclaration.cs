using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGDelegateDeclarationId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGDelegateDeclaration<TValue> where TValue : notnull {
    string GName { get; init; }
    string GType { get; init; }
    string GVisibility { get; init; }
    IGComment<TValue> GComment { get; init; }
    Dictionary<IGArgumentId<TValue>, IGArgument<TValue>> GArguments { get; init; }
    IGDelegateDeclarationId<TValue> Id { get; init; }
  }
}



