using System;
using System.Collections.Generic;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
   public class GPropertyGroup : IGPropertyGroup {
    public GPropertyGroup(string gName, IDictionary<IPhilote<IGProperty>, IGProperty> gPropertys = default) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      if (gPropertys == default) {
        GPropertys = new Dictionary<IPhilote<IGProperty>, IGProperty>();
      }
      else {
        GPropertys = gPropertys;
      }
      Philote = new Philote<IGPropertyGroup>();
    }

    public string GName { get; }
    public IDictionary<IPhilote<IGProperty>, IGProperty> GPropertys { get; init; }
    public IPhilote<IGPropertyGroup> Philote { get; init; }

  }
}
