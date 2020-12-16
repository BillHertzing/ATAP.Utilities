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
  public static partial class GEnumerationMemberExtensions {

    public static GEnumerationMember LocalizableEnumerationMember(string gName = "", int gValue = default, string description = "", string visualDisplay = "", int  visualSortOrder = default) {
      var gAttributeGroups = new Dictionary<Philote<GAttributeGroup>, GAttributeGroup>();
      var gAttributeGroup = CreateLocalizableEnumerationAttributeGroup(description: String.IsNullOrWhiteSpace(description)? gName:description,
        visualDisplay: String.IsNullOrWhiteSpace(visualDisplay)? gName: visualDisplay,
        visualSortOrder:visualSortOrder);
      gAttributeGroups[gAttributeGroup.Philote] = gAttributeGroup;
      return new GEnumerationMember(gName: gName, gValue:gValue, gAttributeGroups: gAttributeGroups);
    }
  }
}
