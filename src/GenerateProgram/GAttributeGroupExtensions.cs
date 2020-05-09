using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace GenerateProgram {
  public static partial class GAttributeGroupExtensions {
    public static GAttributeGroup CreateLocalizableEnumerationAttributeGroup() {
      GAttributeGroup gAttributeGroup =
        new GAttributeGroup(gName: "LocalizableEnumerationAttributeGroup");
      GAttribute gAttribute = new GAttribute(  "Description");
      gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      gAttribute = new GAttribute(  "VisualDisplay");
      gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      gAttribute = new GAttribute(  "VisualSortOrder");
      gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      return gAttributeGroup;
    }
  }
}
