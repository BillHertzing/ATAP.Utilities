using System;
using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GNamespaceId<TValue> : AbstractStronglyTypedId<TValue>, IGNamespaceId<TValue> where TValue : notnull {}
  public class GNamespace<TValue> : IGNamespace<TValue> where TValue : notnull {
    public GNamespace(string gName = "", IDictionary<IGClassId<TValue>, IGClass<TValue>>? gClasss = default,
      IDictionary<IGInterfaceId<TValue>, IGInterface<TValue>>? gInterfaces = default,
      IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>>? gDelegates = default,
      IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>>? gDelegateGroups = default,
      IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>>? gEnumerations = default,
      IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>>? gEnumerationGroups = default,
      //IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>>? gEnumerations = default,
      //IDictionary<IGExceptionId<TValue>, IGException<TValue>>? gExceptions = default
      IGComment gComment = default

      ) {
      GName = gName;
      GClasss = gClasss == default ? new Dictionary<IGClassId<TValue>, IGClass<TValue>>() : gClasss;
      GInterfaces = gInterfaces == default ? new Dictionary<IGInterfaceId<TValue>, IGInterface<TValue>>() : gInterfaces;
      GDelegates = gDelegates == default ? new Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>() : gDelegates;
      GDelegateGroups = gDelegateGroups == default ? new Dictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>>() : gDelegateGroups;
      GEnumerations = gEnumerations == default ? new Dictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups == default ? new Dictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>>() : gEnumerationGroups;
      //GEnumerations = gEnumerations;
      //GExceptions = gExceptions;
      GComment = gComment == default ? new GComment() : gComment;
      Id = new GNamespaceId<TValue>();
    }

    public string GName { get; init; }
    public IDictionary<IGClassId<TValue>, IGClass<TValue>> GClasss { get; init; }
    public IDictionary<IGInterfaceId<TValue>, IGInterface<TValue>> GInterfaces { get; init; }
    public IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> GDelegates { get; init; }
    public IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> GDelegateGroups { get; init; }
    public IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    public IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> GEnumerationGroups { get; init; }
    //public IDictionary<IGExceptionId<TValue>, IGException<TValue>>? GExceptions { get; init; }
    public IGComment GComment { get; init; }
    public  IGNamespaceId Id { get; init; }

  }
}






