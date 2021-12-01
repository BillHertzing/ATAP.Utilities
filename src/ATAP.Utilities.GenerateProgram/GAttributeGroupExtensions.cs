using System.Collections.Generic;

using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.GenerateProgram {
  public static partial class GAttributeGroupExtensions {
    public static IGAttributeGroup CreateLocalizableEnumerationAttributeGroup(string description, string visualDisplay, int  visualSortOrder) {
      GAttributeGroup gAttributeGroup =
        new GAttributeGroup(gName: "LocalizableEnumerationAttributeGroup");
      //GAttribute gAttribute = new GAttribute(  "Description",description);
      //gAttributeGroup.GAttributes[gAttribute.Id] = gAttribute;
      //gAttribute = new GAttribute(  "VisualDisplay", visualDisplay);
      //gAttributeGroup.GAttributes[gAttribute.Id] = gAttribute;
      //gAttribute = new GAttribute(  "VisualSortOrder",visualSortOrder.ToString());
      //gAttributeGroup.GAttributes[gAttribute.Id] = gAttribute;
      return gAttributeGroup;
    }

  }
}



