using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GEnumerationMember : IGEnumerationMember {
    public GEnumerationMember(string gName = "", int? gValue = default,
      IDictionary<IPhilote<IGAttribute>, IGAttribute> gAttributes = default,
      IDictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> gAttributeGroups = default,
      GComment gComment = default
      ) {
      GName = gName;
      GValue = gValue;
      GAttributes = gAttributes == default ? new Dictionary<IPhilote<IGAttribute>, IGAttribute>() : gAttributes;
      GAttributeGroups = gAttributeGroups == default ? new Dictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup>() : gAttributeGroups;
      GComment = gComment == default ? new GComment() : gComment;
      Philote = new Philote<IGEnumerationMember>();
    }

    public string GName { get; init; }
    // ToDo: support for enumeration member types other than int
    public int? GValue { get; init; }
    public IDictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    public IDictionary<IPhilote<IGAttributeGroup>, IGAttributeGroup> GAttributeGroups { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGEnumerationMember> Philote { get; init; }

  }
}
