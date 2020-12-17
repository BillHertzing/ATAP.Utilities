using System;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;
using System.Security.Permissions;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public static partial class GClassExtensions {
    public static IGClass AddTLoggerConstructorAutoPropertyGroup(this IGClass gClass, Philote<IGMethod> gMethodId, Philote<IGPropertyGroup> gPropertyGroupId = default, string? gAccessors = "{ get; }", string? gVisibility = default) {
      IGMethod gMethod = default;
       if (gClass.GMethods != null && gClass.GMethods.ContainsKey(gMethodId)) {
        gMethod = gClass.GMethods[gMethodId];
      }
      else if (gClass.GMethodGroups != null) {
        foreach (var kvp in gClass.GMethodGroups) {
          if (kvp.Value.GMethods.ContainsKey(gMethodId)) {
            var gMethodGroup = kvp.Value;
            gMethod = gMethodGroup.GMethods[gMethodId];
          }
        }
      }
      if (gMethod == null) {
        throw new Exception(string.Format("{0} not found in the Constructors, Methods or MethodGroups of {1}", gMethodId.ID.ToString(), gClass.GName));
      }

      var gMethodDeclaration = gMethod.GDeclaration;
      string gName = gMethodDeclaration.GName;
      GProperty gProperty = new GProperty(gName:$"Logger", gType:$"ILogger<{gName}>",gAccessors:gAccessors);
      if (gClass.GPropertyGroups != null && gClass.GPropertyGroups.ContainsKey(gPropertyGroupId)) {
        gClass.GPropertyGroups[gPropertyGroupId].GPropertys[gProperty.Philote] = gProperty;
      }
      else {
        throw new Exception(string.Format("{0} not found in the PropertyGroups of {1}", gPropertyGroupId.ID.ToString(), gClass.GName));
      }
  
      gMethod.GBody.GStatements.Add($"Logger = LoggerFactory.CreateLogger<{gName}>();");
      return gClass;
    }


  }
}
