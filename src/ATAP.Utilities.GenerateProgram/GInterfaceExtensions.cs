using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Philote;
using ATAP.Utilities.GenerateProgram;
using static ATAP.Utilities.GenerateProgram.GAttributeGroupExtensions;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GInterfaceExtensions {
    public static GInterface AddProperty(this GInterface gInterface, GProperty gProperty) {
      gInterface.GPropertys[gProperty.Philote] = (gProperty);
      return gInterface;
    }
    public static GInterface AddProperty(this GInterface gInterface, IEnumerable<GProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gInterface.GPropertys[o.Philote] = o;
      }
      return gInterface;
    }
    public static GInterface AddProperty(this GInterface gInterface, Dictionary<Philote<GProperty>,GProperty> gPropertys) {
      foreach (var kvp in gPropertys) {
        gInterface.GPropertys.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static GInterface AddPropertyGroups(this GInterface gInterface, GPropertyGroup gPropertyGroup) {
      gInterface.GPropertyGroups[gPropertyGroup.Philote] = gPropertyGroup;
      return gInterface;
    }
    public static GInterface AddPropertyGroups(this GInterface gInterface, IEnumerable<GPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gInterface.GPropertyGroups[o.Philote] = o;
      }
      return gInterface;
    }
    public static GInterface AddPropertyGroup(this GInterface gInterface, Dictionary<Philote<GPropertyGroup>,GPropertyGroup> gPropertyGroups) {
      foreach (var kvp in gPropertyGroups) {
        gInterface.GPropertyGroups.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static GInterface AddMethod(this GInterface gInterface, GMethod gMethod) {
      gInterface.GMethods[gMethod.Philote] = gMethod;
      return gInterface;
    }
    public static GInterface AddMethod(this GInterface gInterface, IEnumerable<GMethod> gMethods) {
      foreach (var o in gMethods) {
        gInterface.GMethods[o.Philote] = o;
      }
      return gInterface;
    }
    public static GInterface AddMethod(this GInterface gInterface, Dictionary<Philote<GMethod>,GMethod> gMethods) {
      foreach (var kvp in gMethods) {
        gInterface.GMethods.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
    public static GInterface AddMethodGroup(this GInterface gInterface, GMethodGroup gMethodGroup) {
      gInterface.GMethodGroups[gMethodGroup.Philote] = gMethodGroup;
      return gInterface;
    }
    public static GInterface AddMethodGroup(this GInterface gInterface, IEnumerable<GMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gInterface.AddMethodGroup(o);
      }
      return gInterface;
    }
    public static GInterface AddMethodGroup(this GInterface gInterface, Dictionary<Philote<GMethodGroup>,GMethodGroup> gMethodGroups) {
      foreach (var kvp in gMethodGroups) {
        gInterface.GMethodGroups.Add(kvp.Key,kvp.Value);
      }
      return gInterface;
    }
  }
}
