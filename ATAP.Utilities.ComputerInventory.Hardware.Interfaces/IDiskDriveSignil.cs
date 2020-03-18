using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDriveSignil
  {
    DiskDriveMaker DiskDriveMaker { get; }
    DiskDriveType DiskDriveType { get; }
    UnitsNet.Information InformationSize { get; }
  }
}
