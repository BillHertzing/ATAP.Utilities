using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGStaticVariableId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGStaticVariable<TValue> where TValue : notnull {
    string GName { get; init; }
    string GType { get; init; }
    string GAccessModifier { get; init; }
    string GVisibility { get; init; }
    IGBody GBody { get; init; }
    IList<string> GAdditionalStatements { get; init; }
    IGComment GComment { get; init; }
    IGStaticVariableId<TValue> Id { get; init; }
  }
}


