using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGProperty {
    string GName { get; }
    string GType { get; }
    string GAccessors { get; }
    string? GVisibility { get; }
    IPhilote<IGProperty> Philote { get; init; }
  }
}
