using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram {
  public interface IGAttribute {
    string GName { get; init; }
    string GValue { get; init; }
    IGComment GComment { get; init; }
    IPhilote<IGAttribute> Philote { get; init; }
  }
}
