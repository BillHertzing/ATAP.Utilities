using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.GenerateProgram.GAttributeGroupExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GClassExtensions<TValue> where TValue : notnull {
    public static IGClass<TValue> AddProperty(this IGClass gClass, IGProperty gProperty) {
      gClass.GPropertys[gProperty.Id] = (gProperty);
      return gClass;
    }
    public static IGClass AddProperty(this IGClass gClass, IEnumerable<IGProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gClass.GPropertys[o.Id] = o;
      }
      return gClass;
    }
    public static IGClass AddProperty(this IGClass gClass, IDictionary<IGPropertyId<TValue>, IGProperty<TValue>> gPropertys) {
      foreach (var kvp in gPropertys) {
        gClass.GPropertys.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddPropertyGroups(this IGClass gClass, IGPropertyGroup gPropertyGroup) {
      gClass.GPropertyGroups[gPropertyGroup.Id] = gPropertyGroup;
      return gClass;
    }
    public static IGClass AddPropertyGroups(this IGClass gClass, IEnumerable<IGPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gClass.GPropertyGroups[o.Id] = o;
      }
      return gClass;
    }
    public static IGClass AddPropertyGroup(this IGClass gClass,
      IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> gPropertyGroups) {
      foreach (var kvp in gPropertyGroups) {
        gClass.GPropertyGroups.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IGMethod gMethod) {
      gClass.GMethods[gMethod.Id] = gMethod;
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IEnumerable<IGMethod> gMethods) {
      foreach (var o in gMethods) {
        gClass.GMethods[o.Id] = o;
      }
      return gClass;
    }
    public static IGClass AddMethod(this IGClass gClass, IDictionary<IGMethodId<TValue>, IGMethod<TValue>> gMethods) {
      foreach (var kvp in gMethods) {
        gClass.GMethods.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass, IGMethodGroup gMethodGroup) {
      gClass.GMethodGroups[gMethodGroup.Id] = gMethodGroup;
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass, IEnumerable<IGMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gClass.AddMethodGroup(o);
      }
      return gClass;
    }
    public static IGClass AddMethodGroup(this IGClass gClass,
      IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> gMethodGroups) {
      foreach (var kvp in gMethodGroups) {
        gClass.GMethodGroups.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IGDelegate gDelegate) {
      gClass.GDelegates[gDelegate.Id] = gDelegate;
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IEnumerable<IGDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        gClass.GDelegates[o.Id] = o;
      }
      return gClass;
    }
    public static IGClass AddDelegate(this IGClass gClass, IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> gDelegates) {
      foreach (var kvp in gDelegates) {
        gClass.GDelegates.Add(kvp.Key, kvp.Value);
      }
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass, IGDelegateGroup gDelegateGroup) {
      gClass.GDelegateGroups[gDelegateGroup.Id] = gDelegateGroup;
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass, IEnumerable<IGDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gClass.AddDelegateGroup(o);
      }
      return gClass;
    }
    public static IGClass AddDelegateGroup(this IGClass gClass,
      IDictionary<IGDelegateGroupId<TValue>, IGDelegateGroup<TValue>> gDelegateGroups) {
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
    public static IEnumerable<KeyValuePair<IGPropertyID, IGProperty>> ConvertToInterfacePropertys(
      this IGClass gClass) {
      //var IEKVP = gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      //Dictionary<IGPropertyId<TValue>, IGProperty<TValue>> t1 = IEKVP.ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      //return gClass.GPropertys.Where(kvp => kvp.Value.GVisibility == "public").ToDictionary(kvp=>kvp.Key,kvp=>kvp.Value);
      return gClass.GPropertys.Where(kvp =>
        kvp.Value.GVisibility == "public");
    }
    public static IDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>> ConvertToInterfacePropertyGroups(
      this IGClass gClass) {
      foreach (var pG in gClass.GPropertyGroups) {
        var newDictionary = new Dictionary<IGPropertyId<TValue>, IGProperty<TValue>>();
        var IEKVP = pG.Value.GPropertys.Where(kvp => kvp.Value.GVisibility == "public");
      }
      //var newDictionary = gClass.GPropertyGroups.Where(x=>x.Value.GVisibility == "public").ToDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>>(x=>x.Value.GVisibility == "public")
      //var newDictionary = gClass.GPropertyGroups.SelectMany(kvp =>
      //  kvp.Value
      //    .Where(x => x.GVisibility == "public")
      //    .ToDictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>>(_ => true);
      return new Dictionary<IGPropertyGroupId<TValue>, IGPropertyGroup<TValue>>();
    }
    public static IGMethod ConvertMethodToInterfaceMethod(IGMethod gMethod) {
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
    public static IDictionary<IGMethodId<TValue>, IGMethod<TValue>> ConvertToInterfaceMethods(this IGClass gClass) {
      var gInterfaceMethods = new Dictionary<IGMethodId<TValue>, IGMethod<TValue>>();
      foreach (var kvp in gClass.GMethods) {
        var gInterfaceMethod = ConvertMethodToInterfaceMethod(kvp.Value);
        if (gInterfaceMethod != default) {
          gInterfaceMethods.Add(gInterfaceMethod.Id, gInterfaceMethod);
        }
      }
      return gInterfaceMethods;
    }
    public static IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> ConvertToInterfaceMethodGroups(this IGClass gClass) {
      var gInterfaceMethodGroups = new Dictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>>();
      IGMethodGroup gInterfaceMethodGroup;
      IGMethod gInterfaceMethod = default;
      foreach (var kvp in gClass.GMethodGroups) {
        gInterfaceMethodGroup = new GMethodGroup(gName: kvp.Value.GName);
        foreach (var mkvp in kvp.Value.GMethods) {
          gInterfaceMethod = ConvertMethodToInterfaceMethod(mkvp.Value);
          if (gInterfaceMethod != default) {
            gInterfaceMethodGroup.GMethods.Add(gInterfaceMethod.Id, gInterfaceMethod);
          }
        }
        gInterfaceMethodGroups.Add(gInterfaceMethodGroup.Id, gInterfaceMethodGroup);
      }
      return gInterfaceMethodGroups;
    }

    //public static IDictionary<IGExceptionId<TValue>, IGException<TValue>> ConvertToInterfaceExceptions(this IGClass gClass) {
    //  return new Dictionary<IGExceptionId<TValue>, IGException<TValue>>();
    //}

    //public static IDictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>> ConvertToInterfaceExceptionGroups(this IGClass gClass) {
    //  return new Dictionary<IGExceptionGroupId<TValue>, IGExceptionGroup<TValue>>();
    //}

    //public static IDictionary<IGEventId<TValue>, IGEvent<TValue>> ConvertToInterfaceEvents(this IGClass gClass) {
    //  return new Dictionary<IGEventId<TValue>, IGEvent<TValue>>();
    //}

    //public static IDictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>> ConvertToInterfaceEventGroups(this IGClass gClass) {
    //  return new Dictionary<IGEventGroupId<TValue>, IGEventGroup<TValue>>();
    //}
    static public void PopulateInterface(IGClass gClass, IGInterface gInterface) {
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



