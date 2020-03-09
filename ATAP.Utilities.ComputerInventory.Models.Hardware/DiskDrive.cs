
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{

  [Serializable]
  public class DiskDrive : IDiskDrive
  {
    public DiskDrive()
    {
    }

    public DiskDrive(IDiskDriveSignil diskDriveSignil, Id<IDiskDrive>? iD, Id<IDiskDrive>? iD2, int? diskDriveNumber, ITimeBlock timeBlock)
    {
      DiskDriveSignil = diskDriveSignil ?? throw new ArgumentNullException(nameof(diskDriveSignil));
      ID = iD;
      ID2 = iD2;
      DiskDriveNumber = diskDriveNumber;
      TimeBlock = timeBlock ?? throw new ArgumentNullException(nameof(timeBlock));
    }

    public IDiskDriveSignil DiskDriveSignil { get; private set; }
    public Id<IDiskDrive>? ID { get; private set; }
    public Id<IDiskDrive>? ID2 { get; private set; }

    public int? DiskDriveNumber { get; private set; }
    public ITimeBlock? TimeBlock { get; }
  }

}
