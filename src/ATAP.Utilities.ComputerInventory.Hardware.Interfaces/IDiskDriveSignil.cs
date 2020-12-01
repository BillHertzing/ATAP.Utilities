using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IDiskDriveSignil
  {
    DiskDriveMaker DiskDriveMaker { get; }
    DiskDriveType DiskDriveType { get; }
    UnitsNet.Information InformationSize { get; }
  }
}
