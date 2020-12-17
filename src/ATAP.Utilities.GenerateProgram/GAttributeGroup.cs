using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {

  public class GAttributeGroup : IGAttributeGroup {
    public GAttributeGroup(string gName = "", Dictionary<IPhilote<IGAttribute>, IGAttribute> gAttributes = default,
      GComment gComment = default
    ) {
      GName = gName;
      GAttributes = gAttributes == default ? new Dictionary<IPhilote<IGAttribute>, IGAttribute>() : gAttributes;
      GComment = gComment == default ? new GComment() : gComment;

      Philote = new Philote<GAttributeGroup>();
    }
    public string GName { get; init; }
    public Dictionary<IPhilote<IGAttribute>, IGAttribute> GAttributes { get; init; }
    public IGComment GComment { get; init; }
    public IPhilote<IGAttributeGroup> Philote { get; init; }
  }
}
