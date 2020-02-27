using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.TypedGuids;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDriveInfoEx
  {

    Id<IDiskDriveInfoEx> DiskDriveDbId { get; set; }
    Id<IDiskDriveInfoEx> DiskDriveId { get; set; }
    DiskDriveMaker DiskDriveMaker { get; set; }
    DiskDriveType DiskDriveType { get; set; }
    int? DriveNumber { get; set; }
    IList<Exception> Exceptions { get; set; }
    IPartitionInfoExs PartitionInfoExs { get; set; }
    string SerialNumber { get; set; }
  }
 
}
