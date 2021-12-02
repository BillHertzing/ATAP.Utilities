using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  

  public interface IGInterfaceId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGInterface<TValue> where TValue : notnull {
    string GName { get; }
    string GVisibility { get; }
    string GAccessModifier { get; }
    string GInheritance { get; }
    IList<string> GImplements { get; }
    IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; }
    IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> GPropertyGroups { get; }
    IDictionary<IGMethodId<TValue>, IGMethod<TValue>> GMethods { get; }
    IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> GMethodGroups { get; }
    IGInterfaceId<TValue> Id { get; }
  }
}



