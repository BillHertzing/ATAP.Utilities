using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGConstString {
    string GName { get; init; }
    string GValue { get; init; }
    IPhilote<IGConstString> Philote { get; init; }
  }
}
