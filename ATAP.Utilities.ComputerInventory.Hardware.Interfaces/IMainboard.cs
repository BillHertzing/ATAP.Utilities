


using ATAP.Utilities.Philote;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IMainBoard
  {
    IMainBoardSignil MainBoardSignil { get; }
    IEnumerable<ICPU>? CPUs { get; }
    IEnumerable<IDiskDrive>? DiskDrives { get; }
    IPhilote<IMainBoard>? Philote { get; }
  }

}
