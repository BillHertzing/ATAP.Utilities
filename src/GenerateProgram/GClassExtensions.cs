using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
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
    public static GClass AddProperty(this GClass gClass, Dictionary<Philote<GProperty>,GProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        gClass.GPropertys.Add(kvp.Key,kvp.Value);
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
    public static GClass AddPropertyGroup(this GClass gClass, Dictionary<Philote<GPropertyGroup>,GPropertyGroup> gPropertyGroups) {
      foreach (var kvp in gPropertyGroups) {
        gClass.GPropertyGroups.Add(kvp.Key,kvp.Value);
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
    public static GClass AddMethod(this GClass gClass, Dictionary<Philote<GMethod>,GMethod> gMethods) {
      foreach (var kvp in gMethods) {
        gClass.GMethods.Add(kvp.Key,kvp.Value);
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
    public static GClass AddMethodGroup(this GClass gClass, Dictionary<Philote<GMethodGroup>,GMethodGroup> gMethodGroups) {
      foreach (var kvp in gMethodGroups) {
        gClass.GMethodGroups.Add(kvp.Key,kvp.Value);
      }
      return gClass;
    }
    public static IEnumerable<GMethod> CombinedMethods(this GClass gClass) {
      foreach (var o in gClass.GMethods) {
        yield return o.Value;
      }
      foreach (var mg in gClass.GMethodGroups) {
        foreach (var o in mg.Value.GMethods) {
          yield return o.Value;
        }
      }
    }
    public static IEnumerable<GMethod> CombinedConstructors(this GClass gClass) {
      foreach (var o in gClass.GMethods) {
        if (o.Value.GDeclaration.IsConstructor) {
          yield return o.Value;
        }
      }
      foreach (var mg in gClass.GMethodGroups) {
        foreach (var o in mg.Value.GMethods) {
          if (o.Value.GDeclaration.IsConstructor) {
            yield return o.Value;
        }
      }
      }
    }
    /*************************************************************************************/
    public static IEnumerable<KeyValuePair<Philote<GProperty>, GProperty>> ConvertToInterfacePropertys(
      this GClass gClass) {
      //var IEKVP = gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      //Dictionary<Philote<GProperty>, GProperty> t1 = IEKVP.ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      //return gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public").ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      return gClass.GPropertys.Where(kvp =>
        kvp.Value.GVisibility == "public");
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

    public static GMethod ConvertMethodToInterfaceMethod(GMethod gMethod) {
      GMethod gInterfaceMethod = default;
      if (!gMethod.GDeclaration.IsConstructor) {
      var gAccessModifier = gMethod.GDeclaration.GAccessModifier;
      var accessModifierRegex = new Regex("(?:override|async|virtual)");
      gAccessModifier = accessModifierRegex.Replace(gAccessModifier, "");
      gInterfaceMethod = new GMethod(new GMethodDeclaration(gMethod.GDeclaration.GName,gMethod.GDeclaration.GType, "",gAccessModifier,gMethod.GDeclaration.IsStatic,false, gMethod.GDeclaration.GArguments,isForInterface:true),gComment:gMethod.GComment, isForInterface:true);
      }
      return gInterfaceMethod;
    }
    public static Dictionary<Philote<GMethod>, GMethod> ConvertToInterfaceMethods(this GClass gClass) {
      var gInterfaceMethods = new Dictionary<Philote<GMethod>, GMethod>();
      foreach (var kvp in  gClass.GMethods) {
        var gInterfaceMethod = ConvertMethodToInterfaceMethod(kvp.Value);
        if (gInterfaceMethod != default) {
        gInterfaceMethods.Add(gInterfaceMethod.Philote,gInterfaceMethod);
        }
      }
      return gInterfaceMethods;
    }
    public static Dictionary<Philote<GMethodGroup>, GMethodGroup> ConvertToInterfaceMethodGroups(this GClass gClass) {
      var gInterfaceMethodGroups =  new Dictionary<Philote<GMethodGroup>, GMethodGroup>();
      GMethodGroup gInterfaceMethodGroup;
      GMethod gInterfaceMethod = default;
      foreach (var kvp in gClass.GMethodGroups) {
        gInterfaceMethodGroup = new GMethodGroup(gName:kvp.Value.GName);
        foreach (var mkvp in kvp.Value.GMethods) {
          gInterfaceMethod = ConvertMethodToInterfaceMethod(mkvp.Value);
          if (gInterfaceMethod != default) {
            gInterfaceMethodGroup.GMethods.Add(gInterfaceMethod.Philote, gInterfaceMethod);
          }
        }
        gInterfaceMethodGroups.Add(gInterfaceMethodGroup.Philote,gInterfaceMethodGroup);
      }
      return gInterfaceMethodGroups;
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

    static public void PopulateInterface(GClass gClass, GInterface gInterface) {
      //gClass.ConvertToInterfacePropertys().ForEach(x => gInterface.GPropertys.Add(x.Key, x.Value));
      //gClass.ConvertToInterfacePropertyGroups().ForEach(x => gInterface.GPropertyGroups.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceMethods().ForEach(x => gInterface.GMethods.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceMethodGroups().ForEach(x => gInterface.GMethodGroups.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceExceptions().ForEach(x => gInterface.GExceptions.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceExceptionGroups().ForEach(x => gInterface.GExceptionGroups.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceEvents().ForEach(x => gInterface.GEvents.Add(x.Key, x.Value));
      //gClass.ConvertToInterfaceEventGroups().ForEach(x => gInterface.GEventGroups.Add(x.Key, x.Value));
      foreach (var kvp in gClass.ConvertToInterfacePropertys()) {
        gInterface.GPropertys.Add(kvp.Key, kvp.Value);
      }
      foreach (var kvp in gClass.ConvertToInterfacePropertyGroups()) {
        gInterface.GPropertyGroups.Add(kvp.Key, kvp.Value);
      }
      //baseClass.ConvertToInterfacePropertyGroups().ForEach(x => gInterface.GPropertyGroups.Add(x.Key, x.Value));
      foreach (var kvp in gClass.ConvertToInterfaceMethods()) {
        gInterface.GMethods.Add(kvp.Key, kvp.Value);
      }
      foreach (var kvp in gClass.ConvertToInterfaceMethodGroups()) {
        gInterface.GMethodGroups.Add(kvp.Key, kvp.Value);
      }
    }

    public static GInterface ConvertToInterface(this GClass gClass) {
      
      var inheritanceRegex1 = new Regex(@":.*?{",RegexOptions.Multiline);
      var gInterfaceInheritance = gClass.GInheritance;
      var gInterfaceImplements = gClass.GImplements;
      var gInterface = new GInterface(
        gName:gClass.GName,
        gVisibility:gClass.GVisibility,
        gImplements:gInterfaceImplements,
        gInheritance:gInterfaceInheritance
      );
      foreach (var kvp in gClass.ConvertToInterfacePropertys()) {
        gInterface.GPropertys.Add(kvp.Key, kvp.Value);
      }
      foreach (var kvp in gClass.ConvertToInterfacePropertyGroups()) {
        gInterface.GPropertyGroups.Add(kvp.Key, kvp.Value);
      }
      foreach (var kvp in gClass.ConvertToInterfaceMethods()) {
        gInterface.GMethods.Add(kvp.Key, kvp.Value);
      }
      foreach (var kvp in gClass.ConvertToInterfaceMethodGroups()) {
        gInterface.GMethodGroups.Add(kvp.Key, kvp.Value);
      }
      //foreach (var kvp in gClass.ConvertToInterfaceExceptionss()) {
      //  gInterface.GExceptionss.Add(kvp.Key, kvp.Value);
      //}
      //foreach (var kvp in gClass.ConvertToInterfaceExceptionsGroups()) {
      //  gInterface.GExceptionsGroups.Add(kvp.Key, kvp.Value);
      //}
      //foreach (var kvp in gClass.ConvertToInterfaceEventss()) {
      //  gInterface.GEventss.Add(kvp.Key, kvp.Value);
      //}
      //foreach (var kvp in gClass.ConvertToInterfaceEventsGroups()) {
      //  gInterface.GEventsGroups.Add(kvp.Key, kvp.Value);
      //}
      //foreach (var kvp in gClass.ConvertToInterfaceConstructors()) {
      //  gInterface.GMethods.Add(kvp.Key, kvp.Value);
      //}
      //foreach (var kvp in gClass.ConvertToInterfaceConstructorGroups()) {
      //  gInterface.GConstructorGroups.Add(kvp.Key, kvp.Value);
      //}
      return gInterface;
    }
  }
}
