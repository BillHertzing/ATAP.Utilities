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
      Dictionary<Philote<GMethod>, GMethod> gConstructors = default,
      Dictionary<Philote<GMethod>, GMethod> gMethods = default,
      Dictionary<Philote<GMethodGroup>, GMethodGroup> gMethodGroups = default,
      Dictionary<Philote<GConstString>, GConstString> gConstStrings = default,
      Dictionary<Philote<GConstStringGroup>, GConstStringGroup> gConstStringGroups = default) {
      GName = gName == default ? "" : gName;
      GVisibility = gVisibility == default ? "" : gVisibility;;
      GAccessModifier = gAccessModifier == default ? "" : gAccessModifier;
      GInheritance = gInheritance == default ? "" : gInheritance;;
      GImplements = gImplements == default? new List<string>() : gImplements;
      GDisposesOf = gDisposesOf == default? new List<string>() : gDisposesOf;
      GPropertyGroups = gPropertyGroups  == default? new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>() : gPropertyGroups;
      GPropertys = gPropertys  == default? new Dictionary<Philote<GProperty>, GProperty>() : gPropertys;
      GConstructors = gConstructors  == default? new Dictionary<Philote<GMethod>, GMethod>() : gConstructors;
      GMethods = gMethods  == default? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      GMethodGroups = gMethodGroups  == default? new Dictionary<Philote<GMethodGroup>, GMethodGroup>() : gMethodGroups;
      GConstStrings = gConstStrings  == default? new Dictionary<Philote<GConstString>, GConstString>() : gConstStrings;
      GConstStringGroups = gConstStringGroups  == default? new Dictionary<Philote<GConstStringGroup>, GConstStringGroup>() : gConstStringGroups;
      Philote = new Philote<GClass>();

    }

    public string GName { get; }
    public string GVisibility { get;  }
    // ToDo: make this an enumeration
    public string GAccessModifier { get; }
    public string GInheritance { get; }
    public List<string>? GImplements { get; }
    public Dictionary<Philote<GProperty>, GProperty> GPropertys { get; }
    public Dictionary<Philote<GPropertyGroup>, GPropertyGroup> GPropertyGroups { get; }
    public Dictionary<Philote<GMethod>, GMethod> GConstructors { get; }
    public Dictionary<Philote<GMethod>, GMethod> GMethods { get; }
    public Dictionary<Philote<GMethodGroup>, GMethodGroup>? GMethodGroups { get; }
    public Dictionary<Philote<GConstString>, GConstString>? GConstStrings { get; }
    public Dictionary<Philote<GConstStringGroup>, GConstStringGroup>? GConstStringGroups { get; }
    public List<string>? GDisposesOf { get; }
    public Philote<GClass> Philote { get; }

  }
}
