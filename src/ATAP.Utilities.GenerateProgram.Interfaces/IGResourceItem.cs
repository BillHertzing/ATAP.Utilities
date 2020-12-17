using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGResourceItem {
    string GName { get; init; }
    string GValue { get; init; }
    string? GComment { get; init; }
    IPhilote<IGResourceItem> Philote { get; init; }
  }
}
