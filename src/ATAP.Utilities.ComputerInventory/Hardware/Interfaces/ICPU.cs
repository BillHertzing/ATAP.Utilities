using ATAP.Utilities.Philote;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface ICPU
  {
    ICPUSignil CPUSignil { get; }
    IGuidPhilote<GuidStronglyTypedId>? Philote { get; }
  }
}
