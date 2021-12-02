using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGStaticVariableGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGStaticVariableGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> GStaticVariables { get; init; }
    IGStaticVariableGroupId<TValue> Id { get; init; }
  }
}



