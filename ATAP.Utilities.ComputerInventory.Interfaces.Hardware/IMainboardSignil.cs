using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IMainBoardSignil
  {
    CPUSocket CPUSocket { get; }
    MainBoardMaker MainBoardMaker { get; }
    int NumberOfX1SlotsMax { get; }
  }
}
