using System;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;
using System.Security.Permissions;
using ATAP.Utilities.Philote;

namespace GenerateProgram {

  public static partial class GClassExtensions {
    public static GClass AddTConstructorAutoProperty(this GClass gClass, Philote<GMethod> gMethodId, string gAutoPropertyName, string gType, string? gAccessors = "{ get;}", string? gVisibility = default) {
      if (gClass.GPropertys != null) {
        GProperty gProperty = new GProperty(gAutoPropertyName.ToUpperFirstChar(), gType, gAccessors, gVisibility);
        gClass.GPropertys[gProperty.Philote] = gProperty;
      }
      GMethod gMethod = default;
      if (gClass.GConstructors != null && gClass.GConstructors.ContainsKey(gMethodId)) {
        gMethod = gClass.GConstructors[gMethodId];
      }
      else if (gClass.GMethods != null && gClass.GMethods.ContainsKey(gMethodId)) {
        gMethod = gClass.GMethods[gMethodId];
      }
      else if ( gClass.GMethodGroups != null) {
        foreach (var kvp in gClass.GMethodGroups) {
          if (kvp.Value.GMethods.ContainsKey(gMethodId)) {
            GMethodGroup gMethodGroup = kvp.Value;
            gMethod = gMethodGroup.GMethods[gMethodId];
          }
        }
      }

      if (gMethod == null) { throw new Exception(string.Format("{0} not found in the Methods or MethodGroups of {1}", gMethodId.ID.ToString(),gClass.GName));
      }

      GMethodArgument gMethodArgument = new GMethodArgument(gAutoPropertyName.ToLowerFirstChar(), gType);
      gMethod.GDeclaration.GMethodArguments[gMethodArgument.Philote] = gMethodArgument;

      gMethod.GBody.StatementList.Add($"{gAutoPropertyName.ToUpperFirstChar()} = {gAutoPropertyName.ToLowerFirstChar()} ?? throw new ArgumentNullException(nameof({gAutoPropertyName.ToLowerFirstChar()}));");
      return gClass;
    }

    public static GClass AddTConstructorAutoProperty(this GClass gClass, Philote<GMethod> gMethodID,  string gAutoPropertyName) {
      string gType = "I" + gAutoPropertyName;
      return gClass.AddTConstructorAutoProperty(gMethodID, gAutoPropertyName, gType);
    }

  }
}
