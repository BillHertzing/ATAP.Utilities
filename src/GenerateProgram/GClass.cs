using System.Collections;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public class GClass {
    //public GClass(string gName, string? gVisibility, string? gInheritance, string[]? gImplements, GPropertyGroup[]? gPropertyGroups, GConstructor[]? gConstructors, GMethod[]? gMethods) {
    public GClass(string gName, string? gVisibility = default, string? gInheritance = default, List<string>? gImplements = default, List<string>? gDisposesOf = default,
      Dictionary<Philote<GProperty>, GProperty>? gPropertys = default, Dictionary<Philote<GPropertyGroup>, GPropertyGroup>? gPropertyGroups = default,  Dictionary<Philote<GMethod>, GMethod>? gConstructors = default,  Dictionary<Philote<GMethod>, GMethod>? gMethods = default,Dictionary<Philote<GMethodGroup>, GMethodGroup>? gMethodGroups = default) {
      GVisibility = gVisibility;
      GName = gName;
      GInheritance = gInheritance;
      GImplements = gImplements == default? new List<string>() : gImplements;
      GDisposesOf = gDisposesOf == default? new List<string>() : gDisposesOf;
      GPropertyGroups = gPropertyGroups  == default? new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>() : gPropertyGroups;
      GPropertys = gPropertys  == default? new Dictionary<Philote<GProperty>, GProperty>() : gPropertys;
      GConstructors = gConstructors  == default? new Dictionary<Philote<GMethod>, GMethod>() : gConstructors;
      GMethods = gMethods  == default? new Dictionary<Philote<GMethod>, GMethod>() : gMethods;
      GMethodGroups = gMethodGroups  == default? new Dictionary<Philote<GMethodGroup>, GMethodGroup>() : gMethodGroups;
      Philote = new Philote<GClass>();

    }

    public string GName { get; }
    public string? GVisibility { get;  }
    public string? GInheritance { get; }
    public List<string>? GImplements { get; }
    public Dictionary<Philote<GProperty>, GProperty>? GPropertys { get; }
    public Dictionary<Philote<GPropertyGroup>, GPropertyGroup>? GPropertyGroups { get; }
    public Dictionary<Philote<GMethod>, GMethod>? GConstructors { get; }
    public Dictionary<Philote<GMethod>, GMethod>? GMethods { get; }
    public Dictionary<Philote<GMethodGroup>, GMethodGroup>? GMethodGroups { get; }
    public List<string>? GDisposesOf { get; }
    public Philote<GClass> Philote { get; }

      
    //public GMethod[]? GMethods { get; }

  }
}
