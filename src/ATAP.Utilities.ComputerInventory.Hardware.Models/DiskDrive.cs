
using ATAP.Utilities.Philote;
using System;

namespace ATAP.Utilities.ComputerInventory.Hardware
{


  [Serializable]
  public class DiskDrive : IDiskDrive
  {
    public DiskDrive()
    {
    }

    public DiskDrive(IDiskDriveSignil diskDriveSignil, int? diskDriveNumber, IPhilote<IDiskDrive> philote)
    {
      DiskDriveSignil = diskDriveSignil ?? throw new ArgumentNullException(nameof(diskDriveSignil));
      DiskDriveNumber = diskDriveNumber;
      Philote = philote ?? throw new ArgumentNullException(nameof(philote));
    }

    public DiskDrive(IDiskDriveSignil diskDriveSignil, int? diskDriveNumber)
    {
      DiskDriveSignil = diskDriveSignil ?? throw new ArgumentNullException(nameof(diskDriveSignil));
      DiskDriveNumber = diskDriveNumber;
      Philote = null;
    }

    public IDiskDriveSignil DiskDriveSignil { get; private set; }
    public int? DiskDriveNumber { get; private set; }
    public IPhilote<IDiskDrive>? Philote { get; private set; }
  }
}

/*
// ToDo: try creating these collections as a dictionary of interfaces keyed by interface
// A Concurrent dictionary structure that participates in R over Observable consisting of the identify collection of PartitionInfoEx(s), keyed by ID<IPartitionInfoEx> 
public interface IDiskDrives
{
  ConcurrentObservableDictionary<Id<DiskDrive>, DiskDrive> DiskDriveCOD { get; set; }
}

public class DiskDrives : IDiskDrives
{
  public DiskDrives() : this(new ConcurrentObservableDictionary<Id<DiskDrive>, DiskDrive>()) { }

  public DiskDrives(ConcurrentObservableDictionary<Id<DiskDrive>, DiskDrive> diskDiskDriveCOD)
  {
    DiskDriveCOD = diskDiskDriveCOD ?? throw new ArgumentNullException(nameof(diskDiskDriveCOD));
  }

  public ConcurrentObservableDictionary<Id<DiskDrive>, DiskDrive> DiskDriveCOD { get; set; }
}
*/
