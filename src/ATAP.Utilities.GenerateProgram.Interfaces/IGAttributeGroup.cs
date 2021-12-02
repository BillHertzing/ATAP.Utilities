using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGAttributeGroupId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGAttributeGroup<TValue> where TValue : notnull {
    string GName { get; init; }
    Dictionary<IGAttributeId<TValue>, IGAttribute<TValue>> GAttributes { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGAttributeGroupId<TValue> Id { get; init; }
  }
}



