using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public class GConstString : IGConstString {
    public GConstString(string gName, string gValue) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      GValue = gValue ?? throw new ArgumentNullException(nameof(gValue));
      Philote = new Philote<IGConstString>();
    }

    public string GName { get; init; }
    public string GValue { get; init; }
    public IPhilote<IGConstString> Philote { get; init; }
  }
}
