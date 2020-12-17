using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGItemGroupInProjectUnit {
    string GName { get; init; }
    string GDescription { get; init; }
    IGBody GBody { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGItemGroupInProjectUnit> Philote { get; init; }
  }
}
