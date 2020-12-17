using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.GenerateProgram.GAttributeGroupExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GClassExtensions {
    public static IGClass AddProperty(this IGClass gClass, IGProperty gProperty) {
      gClass.GPropertys[gProperty.Philote] = (gProperty);
      return gClass;
    }
    public static IGClass AddProperty(this IGClass gClass, IEnumerable<IGProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gClass.GPropertys[o.Philote] = o;
      }
      return gClass;
    }
    public static IGClass AddProperty(this IGClass gClass, IDictionary<IPhilote<IGProperty>, IGProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        gClass.GPropertys.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddPropertyGroups(this IGClass gClass, IGPropertyGroup gPropertyGroup) {
      gClass.GPropertyGroups[gPropertyGroup.Philote] = gPropertyGroup;
      return gClass;
    }
    public static IGClass AddPropertyGroups(this IGClass gClass, IEnumerable<IGPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gClass.GPropertyGroups[o.Philote] = o;
      }
      return gClass;
    }
    public static IGClass AddPropertyGroup(this IGClass gClass,
      IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> gPropertyGroups) {
      foreach (var kvp in gPropertyGroups) {
        gClass.GPropertyGroups.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IGMethod gMethod) {
      gClass.GMethods[gMethod.Philote] = gMethod;
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IEnumerable<IGMethod> gMethods) {
      foreach (var o in gMethods) {
        gClass.GMethods[o.Philote] = o;
      }
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IDictionary<IPhilote<IGMethod>, IGMethod> gMethods) {
      foreach (var kvp in gMethods) {
        gClass.GMethods.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass, IGMethodGroup gMethodGroup) {
      gClass.GMethodGroups[gMethodGroup.Philote] = gMethodGroup;
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass, IEnumerable<IGMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gClass.AddMethodGroup(o);
      }
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass,
      IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> gMethodGroups) {
      foreach (var kvp in gMethodGroups) {
        gClass.GMethodGroups.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IGDelegate gDelegate) {
      gClass.GDelegates[gDelegate.Philote] = gDelegate;
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IEnumerable<IGDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        gClass.GDelegates[o.Philote] = o;
      }
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IDictionary<IPhilote<IGDelegate>, IGDelegate> gDelegates) {
      foreach (var kvp in gDelegates) {
        gClass.GDelegates.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass, IGDelegateGroup gDelegateGroup) {
      gClass.GDelegateGroups[gDelegateGroup.Philote] = gDelegateGroup;
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass, IEnumerable<IGDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gClass.AddDelegateGroup(o);
      }
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass,
      IDictionary<IPhilote<IGDelegateGroup>, IGDelegateGroup> gDelegateGroups) {
      foreach (var kvp in gDelegateGroups) {
        gClass.GDelegateGroups.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IEnumerable<IGMethod> CombinedMethods(this IGClass gClass) {
      foreach (var o in gClass.GMethods) {
        yield return o.Value;
      }
      foreach (var mg in gClass.GMethodGroups) {
        foreach (var o in mg.Value.GMethods) {
          yield return o.Value;
        }
      }
    }
    public static IEnumerable<IGMethod> CombinedConstructors(this IGClass gClass) {
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
    public static IEnumerable<KeyValuePair<IPhilote<IGProperty>, IGProperty>> ConvertToInterfacePropertys(
      this IGClass gClass) {
      //var IEKVP = gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      //Dictionary<Philote<GProperty>, GProperty> t1 = IEKVP.ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      //return gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public").ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      return gClass.GPropertys.Where(kvp =>
        kvp.Value.GVisibility == "public");
    }
    public static IDictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup> ConvertToInterfacePropertyGroups(
      this IGClass gClass) {
      foreach (var pG in gClass.GPropertyGroups) {
        var newDictionary = new Dictionary<IPhilote<IGProperty>, IGProperty>();
        var IEKVP = pG.Value.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      }
      //var newDictionary = gClass.GPropertyGroups.Where(x=>x.Value.GVisibility == "public").ToDictionary<Philote<GPropertyGroup>, GPropertyGroup>(x=>x.Value.GVisibility == "public")
      //var newDictionary = gClass.GPropertyGroups.SelectMany(kvp =>
      //  kvp.Value
      //    .Where(x => x.GVisibility == "public")
      //    .ToDictionary<Philote<GPropertyGroup>, GPropertyGroup>(_ => true);
      return new Dictionary<IPhilote<IGPropertyGroup>, IGPropertyGroup>();
    }
    public static GMethod ConvertMethodToInterfaceMethod(IGMethod gMethod) {
      GMethod gInterfaceMethod = default;
      if (!gMethod.GDeclaration.IsConstructor && gMethod.GDeclaration.GVisibility == "public") {
        var gAccessModifier = gMethod.GDeclaration.GAccessModifier;
        var accessModifierRegex = new Regex("(?:override|async|virtual)");
        gAccessModifier = accessModifierRegex.Replace(gAccessModifier, "");
        gInterfaceMethod = new GMethod(
          new GMethodDeclaration(gMethod.GDeclaration.GName, gMethod.GDeclaration.GType, "", gAccessModifier,
            gMethod.GDeclaration.IsStatic, false, gMethod.GDeclaration.GArguments, isForInterface: true),
          gComment: gMethod.GComment, isForInterface: true);
      }
      return gInterfaceMethod;
    }
    public static IDictionary<IPhilote<IGMethod>, IGMethod> ConvertToInterfaceMethods(this IGClass gClass) {
      var gInterfaceMethods = new Dictionary<IPhilote<IGMethod>, IGMethod>();
      foreach (var kvp in gClass.GMethods) {
        var gInterfaceMethod = ConvertMethodToInterfaceMethod(kvp.Value);
        if (gInterfaceMethod != default) {
          gInterfaceMethods.Add(gInterfaceMethod.Philote, gInterfaceMethod);
        }
      }
      return gInterfaceMethods;
    }
    public static IDictionary<IPhilote<IGMethodGroup>, IGMethodGroup> ConvertToInterfaceMethodGroups(this IGClass gClass) {
      var gInterfaceMethodGroups = new Dictionary<IPhilote<IGMethodGroup>, IGMethodGroup>();
      GMethodGroup gInterfaceMethodGroup;
      GMethod gInterfaceMethod = default;
      foreach (var kvp in gClass.GMethodGroups) {
        gInterfaceMethodGroup = new GMethodGroup(gName: kvp.Value.GName);
        foreach (var mkvp in kvp.Value.GMethods) {
          gInterfaceMethod = ConvertMethodToInterfaceMethod(mkvp.Value);
          if (gInterfaceMethod != default) {
            gInterfaceMethodGroup.GMethods.Add(gInterfaceMethod.Philote, gInterfaceMethod);
          }
        }
        gInterfaceMethodGroups.Add(gInterfaceMethodGroup.Philote, gInterfaceMethodGroup);
      }
      return gInterfaceMethodGroups;
    }

    //public static IDictionary<IPhilote<IGException>, IGException> ConvertToInterfaceExceptions(this IGClass gClass) {
    //  return new Dictionary<IPhilote<IGException>, IGException>();
    //}

    //public static IDictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup> ConvertToInterfaceExceptionGroups(this IGClass gClass) {
    //  return new Dictionary<IPhilote<IGExceptionGroup>, IGExceptionGroup>();
    //}

    //public static IDictionary<iPhilote<iGEvent>, IGEvent> ConvertToInterfaceEvents(this IGClass gClass) {
    //  return new Dictionary<IPhilote<IGEvent>, IGEvent>();
    //}

    //public static IDictionary<IPhilote<IGEventGroup>, IGEventGroup> ConvertToInterfaceEventGroups(this IGClass gClass) {
    //  return new Dictionary<iPhilote<iGEventGroup>, IGEventGroup>();
    //}
    static public void PopulateInterface(GClass gClass, IGInterface gInterface) {
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
    public static IGInterface ConvertToInterface(this IGClass gClass) {
      var inheritanceRegex1 = new Regex(@":.*?{", RegexOptions.Multiline);
      var gInterfaceInheritance = gClass.GInheritance;
      var gInterfaceImplements = gClass.GImplements;
      var gInterface = new GInterface(
        gName: gClass.GName,
        gVisibility: gClass.GVisibility,
        gImplements: gInterfaceImplements,
        gInheritance: gInterfaceInheritance
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
