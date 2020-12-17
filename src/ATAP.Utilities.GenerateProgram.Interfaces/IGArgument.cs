using ATAP.Utilities.Philote;

namespace ATAP.Utilities.GenerateProgram
{
  public interface IGArgument
  {
    string GName { get; init; }
    string GType { get; init; }
    bool IsRef { get; init; }
    bool IsOut { get; init; }
    IPhilote<IGArgument> Philote { get; init; }
  }
}
