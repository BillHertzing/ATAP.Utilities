using System.Collections.Generic;

using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GAttributeGroupExtensions {
    public static IGAttributeGroup CreateLocalizableEnumerationAttributeGroup(string description, string visualDisplay, int  visualSortOrder) {
      GAttributeGroup gAttributeGroup =
        new GAttributeGroup(gName: "LocalizableEnumerationAttributeGroup");
      //GAttribute gAttribute = new GAttribute(  "Description",description);
      //gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      //gAttribute = new GAttribute(  "VisualDisplay", visualDisplay);
      //gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      //gAttribute = new GAttribute(  "VisualSortOrder",visualSortOrder.ToString());
      //gAttributeGroup.GAttributes[gAttribute.Philote] = gAttribute;
      return gAttributeGroup;
    }

  }
}
