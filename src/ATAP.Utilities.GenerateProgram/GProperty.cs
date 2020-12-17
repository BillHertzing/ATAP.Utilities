using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GProperty : IGProperty {
    public GProperty(string gName = default, string gType = default, string gAccessors = "{ get; set; }", string? gVisibility = default) {
      GName = gName == default ? "" : gName;
      GType = gType == default ? "" : gType;
      GAccessors = gAccessors ?? throw new ArgumentNullException(nameof(gAccessors));
      GVisibility = gVisibility == default ? "" : gVisibility;
      Philote = new Philote<GProperty>();
    }

    public string GName { get; }
    public string GType { get; }
    public string GAccessors { get; }
    public string? GVisibility { get; }
    public IPhilote<IGProperty> Philote { get; init; }

  }
}

