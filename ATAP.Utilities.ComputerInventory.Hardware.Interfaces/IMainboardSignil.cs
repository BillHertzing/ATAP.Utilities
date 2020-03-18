namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IMainBoardSignil
  {
    CPUSocket CPUSocket { get; }
    MainBoardMaker MainBoardMaker { get; }
    int NumberOfX1SlotsMax { get; }
  }
}
