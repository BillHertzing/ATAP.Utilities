using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Philote;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IDiskDrive
  {
    int? DiskDriveNumber { get; }
    IDiskDriveSignil DiskDriveSignil { get; }
    IPhilote<IDiskDrive>? Philote { get; }
  }
}
