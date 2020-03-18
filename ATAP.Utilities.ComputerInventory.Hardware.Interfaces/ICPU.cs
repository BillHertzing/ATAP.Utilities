using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface ICPU
  {
    ICPUSignil CPUSignil { get; }
    IPhilote<ICPU>? Philote { get; }
  }
}
