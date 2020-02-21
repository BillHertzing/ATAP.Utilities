using ATAP.Utilities.ComputerInventory.Enumerations;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IMainBoard
  {
    CPUSocket CPUSocket { get;  }
    MainBoardMaker Maker { get; }
  }
}
