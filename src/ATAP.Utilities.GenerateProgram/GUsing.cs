using System;
using System.Collections.Generic;
using System.Text;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public record GUsing : IGUsing {
    public GUsing(string gName) {
      GName = gName ?? throw new ArgumentNullException(nameof(gName));
      Philote = new Philote<IGUsing>();
    }

    public string GName { get; init; }
    public IPhilote<IGUsing> Philote { get; init; }
  }
}