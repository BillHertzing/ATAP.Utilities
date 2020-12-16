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
  public static partial class GNamespaceExtensions {

    public static GNamespace AddDelegate(this GNamespace gNamespace, GDelegate gDelegate) {
      gNamespace.GDelegates[gDelegate.Philote] = (gDelegate);
      return gNamespace;
    }
    public static GNamespace AddDelegate(this GNamespace gNamespace, IEnumerable<GDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        gNamespace.GDelegates[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddDelegate(this GNamespace gNamespace, Dictionary<Philote<GDelegate>, GDelegate> gDelegates) {
      foreach (var kvp in gDelegates) {
        gNamespace.AddDelegate(kvp.Value);
      }
      return gNamespace;
    }
    public static GNamespace AddDelegateGroups(this GNamespace gNamespace, GDelegateGroup gDelegateGroup) {
      gNamespace.GDelegateGroups[gDelegateGroup.Philote] = gDelegateGroup;
      return gNamespace;
    }
    public static GNamespace AddDelegateGroups(this GNamespace gNamespace, IEnumerable<GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddDelegateGroup(this GNamespace gNamespace, IEnumerable<GDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, GEnumeration gEnumeration) {
      gNamespace.GEnumerations[gEnumeration.Philote] = (gEnumeration);
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, IEnumerable<GEnumeration> gEnumerations) {
      foreach (var o in gEnumerations) {
        gNamespace.GEnumerations[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, Dictionary<Philote<GEnumeration>, GEnumeration> gEnumerations) {
      foreach (var kvp in gEnumerations) {
        gNamespace.AddEnumeration(kvp.Value);
      }
      return gNamespace;
    }
    public static GNamespace AddEnumerationGroup(this GNamespace gNamespace, GEnumerationGroup gEnumerationGroup) {
      gNamespace.GEnumerationGroups[gEnumerationGroup.Philote] = gEnumerationGroup;
      return gNamespace;
    }
    public static GNamespace AddEnumerationGroup(this GNamespace gNamespace, IEnumerable<GEnumerationGroup> gEnumerationGroups) {
      foreach (var o in gEnumerationGroups) {
        gNamespace.GEnumerationGroups[o.Philote] = o;
      }
      return gNamespace;
    }
    public static GNamespace AddEnumeration(this GNamespace gNamespace, Dictionary<Philote<GEnumerationGroup>, GEnumerationGroup> gEnumerationGroups) {
      foreach (var kvp in gEnumerationGroups) {
        gNamespace.AddEnumerationGroup(kvp.Value);
      }
      return gNamespace;
    }

   
  }
}
/*

      */
