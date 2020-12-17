using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GClass : IGClass {
    //public GClass(string gName, string? gVisibility, string? gInheritance, string[]? gImplements, GPropertyGroup[]? gPropertyGroups, GConstructor[]? gConstructors, GMethod[]? gMethods) {
    public GClass(string gName = default, string gVisibility = default, string gAccessModifier = default, string gInheritance = default,
      IList<string> gImplements = default,
      IList<string> gDisposesOf = default,
      IDictionary<IPhilote<IGProperty>, IGProperty> gPropertys = default,
      IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> gPropertyGroups = default,
      IDictionary<IPhilote<IGMethod>, IGMethod> gMethods = default,
      IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> gMethodGroups = default,
      IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> gStaticVariables = default,
      IDictionary<IPhilote<IGStaticVariableGroup>, IGStaticVariableGroup> gStaticVariableGroups = default,
      IDictionary<IPhilote<IGConstString>, IGConstString> gConstStrings = default,
      IDictionary<IPhilote<IGConstStringGroup>, IGConstStringGroup> gConstStringGroups = default,
      IDictionary<IPhilote<IGDelegate>, IGDelegate> gDelegates = default,
      IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> gDelegateGroups = default,
      IDictionary<IPhilote<IGEnumeration>, IGEnumeration> gEnumerations = default,
      IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> gEnumerationGroups = default,
      //IDictionary<IPhilote<IGException>, IGException> gExceptions = default,
      //IDictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> gExceptionGroups = default,
      //IDictionary<IPhilote<IGEvent>, IGEvent> gEvents = default,
      //IDictionary<IPhilote<IGEventGroup>, IGEventGroup> gEventGroups = default,
      GComment gComment = default,
      IEnumerable<GStateConfiguration> gStateConfigurations = default
    ) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility; ;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance; ;
      GImplements = gImplements == default ? new List<string>() : gImplements;
      GDisposesOf = gDisposesOf == default ? new List<string>() : gDisposesOf;
      GPropertyGroups = gPropertyGroups == default ? new Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup>() : gPropertyGroups;
      GPropertys = gPropertys == default ? new Dictionary<IPhilote<IGProperty>, IGProperty>() : gPropertys;
      GMethods = gMethods == default ? new Dictionary<IPhilote<IGMethod>, IGMethod>() : gMethods;
      GMethodGroups = gMethodGroups == default ? new Dictionary<IPhilote<IGMethodGroup>,IGMethodGroup>() : gMethodGroups;
      GStaticVariables = gStaticVariables == default ? new Dictionary<IPhilote<IGStaticVariable>, IGStaticVariable>() : gStaticVariables;
      GStaticVariableGroups = gStaticVariableGroups == default ? new Dictionary<IPhilote<IGStaticVariableGroup>, IGStaticVariableGroup>() : gStaticVariableGroups;
      GConstStrings = gConstStrings == default ? new Dictionary<IPhilote<IGConstString>, IGConstString>() : gConstStrings;
      GConstStringGroups = gConstStringGroups == default ? new Dictionary<IPhilote<IGConstStringGroup>, IGConstStringGroup>() : gConstStringGroups;
      GDelegates = gDelegates == default ? new Dictionary<IPhilote<IGDelegate>, IGDelegate>() : gDelegates;
      GDelegateGroups = gDelegateGroups == default ? new Dictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup>() : gDelegateGroups;
      GEnumerations = gEnumerations == default ? new Dictionary<IPhilote<IGEnumeration>, IGEnumeration>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups == default ? new Dictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup>() : gEnumerationGroups;
      //GExceptions = gExceptions  == default? new Dictionary<IPhilote<IGException>, GException>() : gExceptions;
      //GExceptionGroups = gExceptionGroups  == default? new Dictionary<IPhilote<IGExceptionGroup>, GExceptionGroup>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<IPhilote<IGEvent>, GEvent>() : gEvents;
      //GEventGroups = gEventGroups  == default? new Dictionary<IPhilote<IGEventGroup>, GEventGroup>() : gEventGroups;
      GComment = gComment == default ? new GComment() : gComment;
      GStateConfigurations = new List<IGStateConfiguration>();
      if (gStateConfigurations != default) {
        foreach (var sc in gStateConfigurations) {
          GStateConfigurations.Add(sc);
        }
      }

      Philote = new Philote<IGClass>();

    }

    public string GName { get; init; }
    public string GVisibility { get; }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; init; }
    public string GInheritance { get; init; }
    public IList<string> GImplements { get; init; }
    public IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; init; }
    public IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> GPropertyGroups { get; init; }
    public IDictionary<IPhilote<IGMethod>, IGMethod> GMethods { get; init; }
    public IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> GMethodGroups { get; init; }
    public IDictionary<IPhilote<IGStaticVariable>, IGStaticVariable> GStaticVariables { get; init; }
    public IDictionary<IPhilote<IGStaticVariableGroup>, IGStaticVariableGroup> GStaticVariableGroups { get; init; }
    public IDictionary<IPhilote<IGConstString>, IGConstString>? GConstStrings { get; init; }
    public IDictionary<IPhilote<IGConstStringGroup>, IGConstStringGroup>? GConstStringGroups { get; init; }
    public IDictionary<IPhilote<IGDelegate>, IGDelegate> GDelegates { get; init; }
    public IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> GDelegateGroups { get; init; }
    public IDictionary<IPhilote<IGEnumeration>, IGEnumeration> GEnumerations { get; init; }
    public IDictionary<IPhilote<IGEnumerationGroup>, IGEnumerationGroup> GEnumerationGroups { get; init; }
    //public IDictionary<IPhilote<IGException>, IGException> GExceptions { get; init; }
    //public IDictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> GExceptionGroups { get; init; }
    //public IDictionary<IPhilote<IGEvent>, GEvent> IGEvents { get; init; }
    //public IDictionary<IPhilote<IGEventGroup>, IGEventGroup> GEventGroups { get; init; }
    public IList<string>? GDisposesOf { get; init; }
    public IGComment GComment { get; init; }
    public IList<IGStateConfiguration> GStateConfigurations { get; init; }
    public IPhilote<IGClass> Philote { get; init; }

  }
}
