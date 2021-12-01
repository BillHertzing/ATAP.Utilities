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
  public static partial class GNamespaceExtensions {

    public static IGNamespace AddDelegate(this IGNamespace gNamespace, IGDelegate gDelegate) {
      gNamespace.GDelegates[gDelegate.Id] = (gDelegate);
      return gNamespace;
    }
    public static IGNamespace AddDelegate(this IGNamespace gNamespace, IEnumerable<IGDelegate> gDelegates) {
      foreach (var o in gDelegates) {
        gNamespace.GDelegates[o.Id] = o;
      }
      return gNamespace;
    }
    public static IGNamespace AddDelegate(this IGNamespace gNamespace, IDictionary<IGDelegateId<TValue>, IGDelegate<TValue>> gDelegates) {
      foreach (var kvp in gDelegates) {
        gNamespace.AddDelegate(kvp.Value);
      }
      return gNamespace;
    }
    public static IGNamespace AddDelegateGroups(this IGNamespace gNamespace, IGDelegateGroup gDelegateGroup) {
      gNamespace.GDelegateGroups[gDelegateGroup.Id] = gDelegateGroup;
      return gNamespace;
    }
    public static IGNamespace AddDelegateGroups(this IGNamespace gNamespace, IEnumerable<IGDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Id] = o;
      }
      return gNamespace;
    }
    public static IGNamespace AddDelegateGroup(this IGNamespace gNamespace, IEnumerable<IGDelegateGroup> gDelegateGroups) {
      foreach (var o in gDelegateGroups) {
        gNamespace.GDelegateGroups[o.Id] = o;
      }
      return gNamespace;
    }
    public static IGNamespace AddEnumeration(this IGNamespace gNamespace, IGEnumeration gEnumeration) {
      gNamespace.GEnumerations[gEnumeration.Id] = (gEnumeration);
      return gNamespace;
    }
    public static IGNamespace AddEnumeration(this IGNamespace gNamespace, IEnumerable<IGEnumeration> gEnumerations) {
      foreach (var o in gEnumerations) {
        gNamespace.GEnumerations[o.Id] = o;
      }
      return gNamespace;
    }
    public static IGNamespace AddEnumeration(this IGNamespace gNamespace, IDictionary<IGEnumerationId<TValue>, IGEnumeration<TValue>> gEnumerations) {
      foreach (var kvp in gEnumerations) {
        gNamespace.AddEnumeration(kvp.Value);
      }
      return gNamespace;
    }
    public static IGNamespace AddEnumerationGroup(this IGNamespace gNamespace, IGEnumerationGroup gEnumerationGroup) {
      gNamespace.GEnumerationGroups[gEnumerationGroup.Id] = gEnumerationGroup;
      return gNamespace;
    }
    public static IGNamespace AddEnumerationGroup(this IGNamespace gNamespace, IEnumerable<IGEnumerationGroup> gEnumerationGroups) {
      foreach (var o in gEnumerationGroups) {
        gNamespace.GEnumerationGroups[o.Id] = o;
      }
      return gNamespace;
    }

    public static IGNamespace AddEnumeration(this IGNamespace gNamespace, IDictionary<IGEnumerationGroupId<TValue>, IGEnumerationGroup<TValue>> gEnumerationGroups) {
      foreach (var kvp in gEnumerationGroups) {
        gNamespace.AddEnumerationGroup(kvp.Value);
      }
      return gNamespace;
    }
  }
}



