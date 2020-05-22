using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GClass {
    //public GClass(string gName, string? gVisibility, string? gInheritance, string[]? gImplements, GPropertyGroup[]? gPropertyGroups, GConstructor[]? gConstructors, GMethod[]? gMethods) {
    public GClass(string gName = default, string gVisibility = default,  string gAccessModifier = default, string gInheritance = default,
      List<string> gImplements = default,
      List<string> gDisposesOf = default,
      Dictionary<Philote<GProperty>, GProperty> gPropertys = default,
      Dictionary<Philote<GPropertyGroup>, GPropertyGroup> gPropertyGroups = default,
      Dictionary<Philote<GMethod>, GMethod> gMethods = default,
      Dictionary<Philote<GMethodGroup>, GMethodGroup> gMethodGroups = default,
      Dictionary<Philote<GStaticVariable>, GStaticVariable> gStaticVariables = default,
      Dictionary<Philote<GStaticVariableGroup>, GStaticVariableGroup> gStaticVariableGroups = default,
      Dictionary<Philote<GConstString>, GConstString> gConstStrings = default,
      Dictionary<Philote<GConstStringGroup>, GConstStringGroup> gConstStringGroups = default,
      Dictionary<Philote<GDelegate>, GDelegate> gDelegates = default,
        Dictionary<Philote<GDelegateGroup>, GDelegateGroup> gDelegateGroups = default,
      Dictionary<Philote<GEnumeration>, GEnumeration> gEnumerations = default,
      Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup> gEnumerationGroups = default
      //Dictionary<Philote<GException>, GException> gExceptions = default,
      //Dictionary<Philote<GExceptionGroup>, GExceptionGroup> gExceptionGroups = default,
      //Dictionary<Philote<GEvent>, GEvent> gEvents = default,
      //Dictionary<Philote<GEventGroup>, GEventGroup> gEventGroups = default,
    ) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance;;
      GImplements = gImplements == default? new List<string>() : gImplements;
      GDisposesOf = gDisposesOf == default? new List<string>() : gDisposesOf;
      GPropertyGroups = gPropertyGroups  == default? new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>() : gPropertyGroups;
      GPropertys = gPropertys  == default? new Dictionary<Philote<GProperty>, GProperty>() : gPropertys;
      GMethods = gMethods  == default? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      GMethodGroups = gMethodGroups  == default? new Dictionary<Philote<GMethodGroup>, GMethodGroup>() : gMethodGroups;
      GStaticVariables = gStaticVariables  == default? new Dictionary<Philote<GStaticVariable>, GStaticVariable>() : gStaticVariables;
      GStaticVariableGroups = gStaticVariableGroups  == default? new Dictionary<Philote<GStaticVariableGroup>, GStaticVariableGroup>() : gStaticVariableGroups;
      GConstStrings = gConstStrings  == default? new Dictionary<Philote<GConstString>, GConstString>() : gConstStrings;
      GConstStringGroups = gConstStringGroups  == default? new Dictionary<Philote<GConstStringGroup>, GConstStringGroup>() : gConstStringGroups;
      GDelegates = gDelegates  == default? new Dictionary<Philote<GDelegate>, GDelegate>() : gDelegates;
      GDelegateGroups = gDelegateGroups  == default? new Dictionary<Philote<GDelegateGroup>, GDelegateGroup>() : gDelegateGroups;
      GEnumerations = gEnumerations  == default? new Dictionary<Philote<GEnumeration>, GEnumeration>() : gEnumerations;
      GEnumerationGroups = gEnumerationGroups  == default? new Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup>() : gEnumerationGroups;
      //GExceptions = gExceptions  == default? new Dictionary<Philote<GException>, GException>() : gExceptions;
      //GExceptionGroups = gExceptionGroups  == default? new Dictionary<Philote<GExceptionGroup>, GExceptionGroup>() : gExceptionGroups;
      //GEvents = gEvents  == default? new Dictionary<Philote<GEvent>, GEvent>() : gEvents;
      //GEventGroups = gEventGroups  == default? new Dictionary<Philote<GEventGroup>, GEventGroup>() : gEventGroups;
      Philote = new Philote<GClass>();

    }

    public string GName { get; }
    public string GVisibility { get;  }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GInheritance { get; }
    public List<string> GImplements { get; }
    public Dictionary<Philote<GProperty>, GProperty> GPropertys { get; }
    public Dictionary<Philote<GPropertyGroup>, GPropertyGroup> GPropertyGroups { get; }
    public Dictionary<Philote<GMethod>, GMethod> GMethods { get; }
    public Dictionary<Philote<GMethodGroup>, GMethodGroup> GMethodGroups { get; }
    public Dictionary<Philote<GStaticVariable>, GStaticVariable> GStaticVariables { get; }
    public Dictionary<Philote<GStaticVariableGroup>, GStaticVariableGroup> GStaticVariableGroups { get; }
    public Dictionary<Philote<GConstString>, GConstString>? GConstStrings { get; }
    public Dictionary<Philote<GConstStringGroup>, GConstStringGroup>? GConstStringGroups { get; }
    public Dictionary<Philote<GDelegate>, GDelegate> GDelegates { get; }
    public Dictionary<Philote<GDelegateGroup>, GDelegateGroup> GDelegateGroups { get; }
    public Dictionary<Philote<GEnumeration>, GEnumeration> GEnumerations { get; }
    public Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup> GEnumerationGroups { get; }
    //public Dictionary<Philote<GException>, GException> GExceptions { get; }
    //public Dictionary<Philote<GExceptionGroup>, GExceptionGroup> GExceptionGroups { get; }
    //public Dictionary<Philote<GEvent>, GEvent> GEvents { get; }
    //public Dictionary<Philote<GEventGroup>, GEventGroup> GEventGroups { get; }
    public List<string>? GDisposesOf { get; }
    public Philote<GClass> Philote { get; }

  }
}
