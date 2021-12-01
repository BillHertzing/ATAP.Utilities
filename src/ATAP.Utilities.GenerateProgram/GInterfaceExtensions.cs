using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.GenerateProgram.GAttributeGroupExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GInterfaceExtensions {
    public static IGInterface AddProperty(this IGInterface gInterface, IGProperty gProperty) {
      gInterface.GPropertys[gProperty.Id] = (gProperty);
      return gInterface;
    }
    public static IGInterface AddProperty(this IGInterface gInterface, IEnumerable<IGProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gInterface.GPropertys[o.Id] = o;
      }
      return gInterface;
    }
    public static IGInterface AddProperty(this IGInterface gInterface, IDictionary<IGProperty>,IGProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        gInterface.GPropertys.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static IGInterface AddPropertyGroups(this IGInterface gInterface, IGPropertyGroup gPropertyGroup) {
      gInterface.GPropertyGroups[gPropertyGroup.Id] = gPropertyGroup;
      return gInterface;
    }
    public static IGInterface AddPropertyGroups(this IGInterface gInterface, IEnumerable<IGPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gInterface.GPropertyGroups[o.Id] = o;
      }
      return gInterface;
    }
    public static IGInterface AddPropertyGroup(this IGInterface gInterface, IDictionary<IGPropertyGroupId<TValue>, IGProperty>,IGProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        gInterface.GPropertys.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static IGInterface AddPropertyGroups(this IGInterface gInterface, IGPropertyGroup gPropertyGroup) {
      gInterface.GPropertyGroups[gPropertyGroup.Id] = gPropertyGroup;
      return gInterface;
    }
    public static IGInterface AddPropertyGroups(this IGInterface gInterface, IEnumerable<IGPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gInterface.GPropertyGroups[o.Id] = o;
      }
      return gInterface;
    }
    public static IGInterface AddPropertyGroup(this IGInterface gInterface, IDictionary<IPhilote<IGPropertyGroup<TValue>> gPropertyGroups) {
      foreach (var kvp in gPropertyGroups) {
        gInterface.GPropertyGroups.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static IGInterface AddMethod(this IGInterface gInterface, IGMethod gMethod) {
      gInterface.GMethods[gMethod.Id] = gMethod;
      return gInterface;
    }
    public static IGInterface AddMethod(this IGInterface gInterface, IEnumerable<GMethod> gMethods) {
      foreach (var o in gMethods) {
        gInterface.GMethods[o.Id] = o;
      }
      return gInterface;
    }
    public static IGInterface AddMethod(this IGInterface gInterface, IDictionary<IGMethodId<TValue>, IGMethod<TValue>> gMethods) {
      foreach (var kvp in gMethods) {
        gInterface.GMethods.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static IGInterface AddMethodGroup(this IGInterface gInterface, IGMethodGroup gMethodGroup) {
      gInterface.GMethodGroups[gMethodGroup.Id] = gMethodGroup;
      return gInterface;
    }
    public static IGInterface AddMethodGroup(this IGInterface gInterface, IEnumerable<IGMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gInterface.AddMethodGroup(o);
      }
      return gInterface;
    }
    public static IGInterface AddMethodGroup(this IGInterface gInterface, IDictionary<IGMethodGroupId<TValue>, IGMethodGroup<TValue>> gMethodGroups) {
      foreach (var kvp in gMethodGroups) {
        gInterface.GMethodGroups.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
  }
}



