using System;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;
using System.Security.Permissions;
using ATAP.Utilities.Philote;

namespace GenerateProgram {

  public static partial class GClassExtensions {
    public static GClass AddTLocalizerConstructorAutoPropertyGroup(this GClass gClass, Philote<GMethod> gMethodId, string gAutoPropertyName,  string assemblyUnitName, Philote<GPropertyGroup> gPropertyGroupId = default, string? gAccessors = "{ get; }", string? gVisibility = default) {
      GMethod gMethod = default;
      if (gClass.GConstructors != null && gClass.GConstructors.ContainsKey(gMethodId)) {
        gMethod = gClass.GConstructors[gMethodId];
      }
      else if (gClass.GMethods != null && gClass.GMethods.ContainsKey(gMethodId)) {
        gMethod = gClass.GMethods[gMethodId];
      }
      else if (gClass.GMethodGroups != null) {
        foreach (var kvp in gClass.GMethodGroups) {
          if (kvp.Value.GMethods.ContainsKey(gMethodId)) {
            //GMethodGroup gMethodGroup = kvp.Value;
            gMethod = kvp.Value.GMethods[gMethodId];
          }
        }
      }
      if (gMethod == null) {
        throw new Exception(string.Format("{0} not found in the Constructors, Methods or MethodGroups of {1}", gMethodId.ID.ToString(), gClass.GName));
      }

      GMethodDeclaration gMethodDeclaration = gMethod.GDeclaration;
      string gName = gMethodDeclaration.GName;
      GProperty gProperty = new GProperty(gName:$"{gAutoPropertyName}", gType:$"IStringLocalizer",gAccessors:gAccessors);
      if (gClass.GPropertyGroups != null && gClass.GPropertyGroups.ContainsKey(gPropertyGroupId)) {
        gClass.GPropertyGroups[gPropertyGroupId].GPropertys[gProperty.Philote] = gProperty;
      }
      else {
        throw new Exception(string.Format("{0} not found in the PropertyGroups of {1}", gPropertyGroupId.ID.ToString(), gClass.GName));
      }
  
      //gMethod.GBody.StatementList.Add($"{gAutoPropertyName} = StringLocalizerFactory.Create(nameof({assemblyUnitName}.Resources), \"{assemblyUnitName}\");");
      gMethod.GBody.GStatements.Add($"{gAutoPropertyName} = StringLocalizerFactory.Create(nameof(Resources), \"{assemblyUnitName}\");");
      return gClass;
    }


  }
}
