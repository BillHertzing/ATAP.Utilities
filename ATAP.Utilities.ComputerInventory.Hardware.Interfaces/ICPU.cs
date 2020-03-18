using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface ICPU
  {
    ICPUSignil CPUSignil { get; }
    Id<Interfaces.Hardware.ICPU>? ID { get; }
    ITimeBlock? TimeBlock { get; }
  }
}
