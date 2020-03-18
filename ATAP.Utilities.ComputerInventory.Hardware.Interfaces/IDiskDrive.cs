using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDrive
  {
    int? DiskDriveNumber { get; }
    IDiskDriveSignil DiskDriveSignil { get; }
    Id<IDiskDrive>? ID { get; }
    Id<IDiskDrive>? ID2 { get; }
    ITimeBlock TimeBlock { get; }
  }
}
