using System;
using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GInterfaceId<TValue> : AbstractStronglyTypedId<TValue>, IGInterfaceId<TValue> where TValue : notnull {}
  public class GInterface<TValue> : IGInterface<TValue> where TValue : notnull {
    public GInterface(string gName, string gVisibility = default, string gAccessModifier = default, string gInheritance = default,
      IList<string> gImplements = default,
      IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> gPropertys = default,
      IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> gPropertyGroups = default,
      IDictionary<IGMethodId<TValue>, IGMethod<TValue>> gMethods = default,
      IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> gMethodGroups = default
      //IDictionary<IGExceptionId<TValue>, IGException<TValue>> gExceptions = default,
      //IDictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>> gExceptionGroups = default,
      //IDictionary<IGEventId<TValue>, IGEvent<TValue>> gEvents = default,
      //IDictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>> gEventGroups = default,
      ) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GVisibility = gVisibility == default ? "" : gVisibility; ;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      GImplements = gImplements == default ? new List<string>() : gImplements;
      GPropertys = gPropertys == default ? new Dictionary<IGPropertyId<TValue>, IGProperty<TValue>>() : gPropertys;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>>() : gPropertyGroups;
      GMethods = gMethods == default ? new Dictionary<IGMethodId<TValue>, IGMethod<TValue>>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>>() : gMethodGroups;
      //GExceptions = gExceptions  == default? new Dictionary<IGExceptionId<TValue>, IGException<TValue>>() : gExceptions;
      //GExceptionGroups = gExceptionGroups == default ? new Dictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<IGEventId<TValue>, IGEvent<TValue>>() : gEvents;
      //GEventGroups = gEventGroups == default ? new Dictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>>() : gEventGroups;

      Id = new GInterfaceId<TValue>();
    }
    public string GName { get; }
    public string GVisibility { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GInheritance { get; }
    public IList<string> GImplements { get; }
    public IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; }
    public IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> GPropertyGroups { get; }
    public IDictionary<IGMethodId<TValue>, IGMethod<TValue>> GMethods { get; }
    public IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> GMethodGroups { get; }
    //public IDictionary<IGExceptionId<TValue>, IGException<TValue>> GExceptions { get; }
    //public IDictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>> GExceptionGroups { get; }
    //public IDictionary<IGEventId<TValue>, IGEvent<TValue>> GEvents { get; }
    //public IDictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>> GEventGroups { get; }
    public  IGInterfaceId Id { get; }
  }
}







