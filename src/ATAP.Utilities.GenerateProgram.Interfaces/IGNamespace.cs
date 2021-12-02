using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {


  public interface IGNamespaceId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull {}
  public interface IGNamespace<TValue> where TValue : notnull {
    string GName { get; init; }
    IDictionary<IGClassId<TValue>, IGClass<TValue>> GClasss { get; init; }
    IDictionary<IGInterfaceId<TValue>, IGInterface<TValue>> GInterfaces { get; init; }
    IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> GDelegates { get; init; }
    IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> GDelegateGroups { get; init; }
    IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> GEnumerationGroups { get; init; }
    IGComment<TValue> GComment { get; init; }
    IGNamespaceId<TValue> Id { get; init; }
  }
}



