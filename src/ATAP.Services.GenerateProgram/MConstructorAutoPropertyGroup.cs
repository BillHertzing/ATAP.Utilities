using System;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;
using System.Security.Permissions;
using ATAP.Utilities.Philote;

namespace GenerateProgram {

  public static partial class GClassExtensions {
    public static GClass AddTConstructorAutoPropertyGroup(this GClass gClass, Philote<GMethod> gMethodId, string gAutoPropertyName, string gType, Philote<GPropertyGroup> gPropertyGroupId = default, string? gAccessors = "{ get;}", string? gVisibility = default) {
      GProperty gProperty= new GProperty(gAutoPropertyName.ToUpperFirstChar(), gType, gAccessors, gVisibility);
      if (gClass.GPropertyGroups != null && gClass.GPropertyGroups.ContainsKey(gPropertyGroupId)) {
        gClass.GPropertyGroups[gPropertyGroupId].GPropertys[gProperty.Philote] = gProperty;
      }
      else {
        throw new Exception(string.Format("{0} not found in the PropertyGroups of {1}", gPropertyGroupId.ID.ToString(), gClass.GName));
      }
      GMethod gMethod = default;
      if (gClass.GMethods != null && gClass.GMethods.ContainsKey(gMethodId)) {
        gMethod = gClass.GMethods[gMethodId];
      }
      else if (gClass.GMethodGroups != null) {
        foreach (var kvp in gClass.GMethodGroups) {
          if (kvp.Value.GMethods.ContainsKey(gMethodId)) {
            GMethodGroup gMethodGroup = kvp.Value;
            gMethod = gMethodGroup.GMethods[gMethodId];
          }
        }
      }

      if (gMethod == null) {
        throw new Exception(string.Format("{0} not found in the Methods or MethodGroups of {1}", gMethodId.ID.ToString(), gClass.GName));
      }

      GArgument gArgument = new GArgument(gAutoPropertyName.ToLowerFirstChar(), gType);
      gMethod.GDeclaration.GArguments[gArgument.Philote] = gArgument;

      gMethod.GBody.GStatements.Add($"{gAutoPropertyName.ToUpperFirstChar()} = {gAutoPropertyName.ToLowerFirstChar()} ?? throw new ArgumentNullException(nameof({gAutoPropertyName.ToLowerFirstChar()}));");
      return gClass;
    }

    public static GClass AddTConstructorAutoPropertyGroup(this GClass gClass, Philote<GMethod> gMethodId, string gAutoPropertyName, Philote<GPropertyGroup> gPropertyGroupId) {
      string gType = "I" + gAutoPropertyName;
      return gClass.AddTConstructorAutoPropertyGroup(gMethodId, gAutoPropertyName, gType, gPropertyGroupId);
    }

  }
}