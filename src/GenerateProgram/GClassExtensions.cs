using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using GenerateProgram;

namespace GenerateProgram
{
  public static partial class GClassExtensions
  {
    public static GClass AddPropertys(this GClass gClass,  GProperty gProperty) {
      gClass.GPropertys[gProperty.Philote] = (gProperty);
      return gClass;
    }
    public static GClass AddPropertys(this GClass gClass,  IEnumerable<GProperty> gPropertys) {
      foreach (var o in gPropertys) {
        gClass.GPropertys[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddPropertyGroups(this GClass gClass,  GPropertyGroup gPropertyGroup) {
      gClass.GPropertyGroups[gPropertyGroup.Philote] = gPropertyGroup;
      return gClass;
    }
    public static GClass AddPropertyGroups(this GClass gClass,  IEnumerable<GPropertyGroup> gPropertyGroups) {
      foreach (var o in gPropertyGroups) {
        gClass.GPropertyGroups[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddMethod(this GClass gClass,  GMethod gMethod) {
      gClass.GMethods[gMethod.Philote] = gMethod;
      return gClass;
    }
    public static GClass AddMethod(this GClass gClass,  IEnumerable<GMethod> gMethods) {
      foreach (var o in gMethods) {
        gClass.GMethods[o.Philote] = o;
      }
      return gClass;
    }
    public static GClass AddMethodGroup(this GClass gClass,  GMethodGroup gMethodGroup) {
      gClass.GMethodGroups[gMethodGroup.Philote] = gMethodGroup;
      return gClass;
    }
    public static GClass AddMethodGroup(this GClass gClass,  IEnumerable<GMethodGroup> gMethodGroups) {
      foreach (var o in gMethodGroups) {
        gClass.AddMethodGroup(o);
      }
      return gClass;
    }
  }
}
