using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using GenerateProgram;
using static GenerateProgram.GAttributeGroupExtensions;

namespace GenerateProgram {
  public static partial class GClassExtensions {
    public static GClass AddProperty(this GClass gClass, GProperty gProperty) {
      gClass.GPropertys[gProperty.Philote] = (gProperty);
      return gClass;
    }
    public static GClass AddProperty(this GClass gClass, IEnumerable<GProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gClass.GPropertys[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddPropertyGroups(this GClass gClass, GPropertyGroup gPropertyGroup) {
      gClass.GPropertyGroups[gPropertyGroup.Philote] = gPropertyGroup;
      return gClass;
    }
    public static GClass AddPropertyGroups(this GClass gClass, IEnumerable<GPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gClass.GPropertyGroups[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddMethod(this GClass gClass, GMethod gMethod) {
      gClass.GMethods[gMethod.Philote] = gMethod;
      return gClass;
    }
    public static GClass AddMethod(this GClass gClass, IEnumerable<GMethod> gMethods) {
      foreach (var o in gMethods) {
        gClass.GMethods[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddMethodGroup(this GClass gClass, GMethodGroup gMethodGroup) {
      gClass.GMethodGroups[gMethodGroup.Philote] = gMethodGroup;
      return gClass;
    }
    public static GClass AddMethodGroup(this GClass gClass, IEnumerable<GMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gClass.AddMethodGroup(o);
      }
      return gClass;
    }
    public static IEnumerable<KeyValuePair<Philote<GProperty>, GProperty>> ConvertToInterfacePropertys(
      this GClass gClass) {
      //var IEKVP = gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      //Dictionary<Philote<GProperty>, GProperty> t1 = IEKVP.ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      //return gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public").ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      return gClass.GPropertys.Where(kvp =>
        kvp.Value.GVisibility == "public" || kvp.Value.GVisibility == "protected internal");
    }
    public static Dictionary<Philote<GPropertyGroup>, GPropertyGroup> ConvertToInterfacePropertyGroups(
      this GClass gClass) {
      foreach (var pG in gClass.GPropertyGroups) {
        var newDictionary = new Dictionary<Philote<GProperty>, GProperty>();
        var IEKVP = pG.Value.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      }
      //var newDictionary = gClass.GPropertyGroups.Where(x=>x.Value.GVisibility == "public").ToDictionary<Philote<GPropertyGroup>, GPropertyGroup>(x=>x.Value.GVisibility == "public")
      //var newDictionary = gClass.GPropertyGroups.SelectMany(kvp =>
      //  kvp.Value
      //    .Where(x => x.GVisibility == "public")
      //    .ToDictionary<Philote<GPropertyGroup>, GPropertyGroup>(_ => true);
      return new Dictionary<Philote<GPropertyGroup>, GPropertyGroup>();
    }
    public static Dictionary<Philote<GMethod>, GMethod> ConvertToInterfaceMethods(this GClass gClass) {
      return gClass.GMethods
        .Where(kvp => kvp.Value.GDeclaration.GVisibility == "public" ||
                      kvp.Value.GDeclaration.GVisibility == "protected internal" ||
                      kvp.Value.GDeclaration.IsConstructor == true).ToDictionary(kvp => kvp.Key, kvp => kvp.Value);
    }
    public static Dictionary<Philote<GMethodGroup>, GMethodGroup> ConvertToInterfaceMethodGroups(this GClass gClass) {
      return new Dictionary<Philote<GMethodGroup>, GMethodGroup>();
    }

    //public static Dictionary<Philote<GException>, GException> ConvertToInterfaceExceptions(this GClass gClass) {
    //  return new Dictionary<Philote<GException>, GException>();
    //}

    //public static Dictionary<Philote<GExceptionGroup>, GExceptionGroup> ConvertToInterfaceExceptionGroups(this GClass gClass) {
    //  return new Dictionary<Philote<GExceptionGroup>, GExceptionGroup>();
    //}

    //public static Dictionary<Philote<GEvent>, GEvent> ConvertToInterfaceEvents(this GClass gClass) {
    //  return new Dictionary<Philote<GEvent>, GEvent>();
    //}

    //public static Dictionary<Philote<GEventGroup>, GEventGroup> ConvertToInterfaceEventGroups(this GClass gClass) {
    //  return new Dictionary<Philote<GEventGroup>, GEventGroup>();
    //}
  }
}
