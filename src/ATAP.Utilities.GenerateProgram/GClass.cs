using System.Collections.Generic;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {

  public record GClassId<TValue> : AbstractStronglyTypedId<TValue>, IGClassId<TValue> where TValue : notnull {}
  public class GClass<TValue> : IGClass<TValue> where TValue : notnull {
    //public GClass(string gName, string? gVisibility, string? gInheritance, string[]? gImplements, GPropertyGroup[]? gPropertyGroups, GConstructor[]? gConstructors, GMethod[]? gMethods) {
    public GClass(string gName = default, string gVisibility = default, string gAccessModifier = default, string gInheritance = default,
      IList<string> gImplements = default,
      IList<string> gDisposesOf = default,
      IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> gPropertys = default,
      IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> gPropertyGroups = default,
      IDictionary<IGMethodId<TValue>, IGMethod<TValue>> gMethods = default,
      IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> gMethodGroups = default,
      IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> gStaticVariables = default,
      IDictionary<IGStaticVariableGroupId<TValue>, IGStaticVariableGroup<TValue>> gStaticVariableGroups = default,
      IDictionary<IGConstStringId<TValue>, IGConstString<TValue>> gConstStrings = default,
      IDictionary<IGConstStringGroupId<TValue>, IGConstStringGroup<TValue>> gConstStringGroups = default,
      IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> gDelegates = default,
      IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> gDelegateGroups = default,
      IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> gEnumerations = default,
      IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> gEnumerationGroups = default,
      //IDictionary<IGExceptionId<TValue>, IGException<TValue>> gExceptions = default,
      //IDictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>> gExceptionGroups = default,
      //IDictionary<IGEventId<TValue>, IGEvent<TValue>> gEvents = default,
      //IDictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>> gEventGroups = default,
      GComment gComment = default,
      IEnumerable<GStateConfiguration> gStateConfigurations = default
    ) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility; ;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      GImplements = gImplements == default ? new List<string>() : gImplements;
      GDisposesOf = gDisposesOf == default ? new List<string>() : gDisposesOf;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>>() : gPropertyGroups;
      GPropertys = gPropertys == default ? new Dictionary<IGPropertyId<TValue>, IGProperty<TValue>>() : gPropertys;
      GMethods = gMethods == default ? new Dictionary<IGMethodId<TValue>, IGMethod<TValue>>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<IGMethodGroupId<TValue>,IGMethodGroup<TValue>>() : gMethodGroups;
      GStaticVariables = gStaticVariables == default ? new Dictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>>() : gMethodGroups;
      GStaticVariableGroups = gStaticVariableGroups == default ? new Dictionary<IGStaticVariableGroupId<TValue>, IGStaticVariableGroup<TValue>>() : gStaticVariableGroups;
      GConstStrings = gConstStrings == default ? new Dictionary<IGConstStringId<TValue>, IGConstString<TValue>>() : gConstStrings;
      GConstStringGroups = gConstStringGroups == default ? new Dictionary<IGConstStringGroupId<TValue>, IGConstStringGroup<TValue>>() : gConstStringGroups;
      GDelegates = gDelegates == default ? new Dictionary<IGDelegateId<TValue>, IGDelegate<TValue>>() : gDelegates;
      GDelegateGroups = gDelegateGroups == default ? new Dictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>>() : gDelegateGroups;
      GEnumerations = gEnumerations == default ? new Dictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups == default ? new Dictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>>() : gEnumerationGroups;
      //GExceptions = gExceptions  == default? new Dictionary<IGExceptionId<TValue>, IGException<TValue>>() : gExceptions;
      //GExceptionGroups = gExceptionGroups  == default? new Dictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<IGEventId<TValue>, IGEvent<TValue>>() : gEvents;
      //GEventGroups = gEventGroups  == default? new Dictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>>() : gEventGroups;
      GComment = gComment == default ? new GComment() : gComment;
      GStateConfigurations = new List<IGStateConfiguration>();
      if (gStateConfigurations != default) {
        foreach (var sc in gStateConfigurations) {
          GStateConfigurations.Add(sc);
        }
      }

      Id = new GClassId<TValue>();

    }

    public string GName { get; init; }
    public string GVisibility { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GInheritance { get; init; }
    public IList<string> GImplements { get; init; }
    public IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> GPropertys { get; init; }
    public IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> GPropertyGroups { get; init; }
    public IDictionary<IGMethodId<TValue>, IGMethod<TValue>> GMethods { get; init; }
    public IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> GMethodGroups { get; init; }
    public IDictionary<IGStaticVariableId<TValue>, IGStaticVariable<TValue>> GStaticVariables { get; init; }
    public IDictionary<IGStaticVariableGroupId<TValue>, IGStaticVariableGroup<TValue>> GStaticVariableGroups { get; init; }
    public IDictionary<IGConstStringId<TValue>, IGConstString<TValue>>? GConstStrings { get; init; }
    public IDictionary<IGConstStringGroupId<TValue>, IGConstStringGroup<TValue>>? GConstStringGroups { get; init; }
    public IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> GDelegates { get; init; }
    public IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> GDelegateGroups { get; init; }
    public IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> GEnumerations { get; init; }
    public IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> GEnumerationGroups { get; init; }
    //public IDictionary<IGExceptionId<TValue>, IGException<TValue>> GExceptions { get; init; }
    //public IDictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>> GExceptionGroups { get; init; }
    //public IDictionary<IGEventId<TValue>, IGEvent<TValue>> IGEvents { get; init; }
    //public IDictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>> GEventGroups { get; init; }
    public IList<string>? GDisposesOf { get; init; }
    public IGComment GComment { get; init; }
    public IList<IGStateConfiguration> GStateConfigurations { get; init; }
    public  IGClassId Id { get; init; }

  }
}






