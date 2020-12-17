using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGUsing
  {
    string GName { get; init; }
    IPhilote<IGUsing>? Philote { get; init; }
  }
}
