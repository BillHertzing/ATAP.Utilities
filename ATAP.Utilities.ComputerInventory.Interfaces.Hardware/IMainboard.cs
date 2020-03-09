


using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IMainBoard
  {
    ICPU[] CPUs { get; }
    IMainBoardSignil MainBoardSignil { get; }
    Id<IMainBoard>? ID { get; }
    ITimeBlock? TimeBlock { get; }
  }

}
