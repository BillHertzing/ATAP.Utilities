
using ATAP.Utilities.Philote;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public partial class PartitionInfoEx : IPartitionInfoEx
  {
    public PartitionInfoEx()
    {
    }

    public PartitionInfoEx(PartitionFileSystem partitionFileSystem, Information size, IEnumerable<char>? driveLetters, IPhilote<IPartitionInfoEx>? philote)
    {
      PartitionFileSystem = partitionFileSystem;
      Size = size;
      DriveLetters = driveLetters;
      Philote = philote;
    }

    public PartitionFileSystem PartitionFileSystem { get; private set; }
    public UnitsNet.Information Size { get; private set; }
    public IEnumerable<char>? DriveLetters { get; private set; }
    public IPhilote<IPartitionInfoEx>? Philote { get; private set; }
  }
}
/*
 
// ToDo: try creating these collections as a dictionary of interfaces keyed by interface
// A Concurrent dictionary structure that participates in R over Observable consisting of the identify collection of PartitionInfoEx(s), keyed by ID<IPartitionInfoEx> 
public interface IPartitionInfoExs
  {
    ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> PartitionInfoExCOD { get; set; }
  }

  public class PartitionInfoExs : IPartitionInfoExs
  {
    public PartitionInfoExs() : this(new ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx>()) { }

    public PartitionInfoExs(ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> partitionInfoExCOD)
    {
      PartitionInfoExCOD = partitionInfoExCOD ?? throw new ArgumentNullException(nameof(partitionInfoExCOD));
    }

    public ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> PartitionInfoExCOD { get; set; }
  }

  /* 
  // The dictionary that associates multiple PartitionInfoEx with DiskDrive
      public interface IDiskDrivePartitionIdentifier {
          ConcurrentObservableDictionary<Id<DiskDrive>, IPartitionInfoExs> DiskDriveOneToManyIPartitionInfoExsCOD { get; set; }
      }

      public class DiskDrivePartitionIdentifier : IEquatable<DiskDrivePartitionIdentifier>, IDiskDrivePartitionIdentifier {
          public DiskDrivePartitionIdentifier() :this (new ConcurrentObservableDictionary<Id<DiskDrive>, IPartitionInfoExs>()) {}

          public DiskDrivePartitionIdentifier(ConcurrentObservableDictionary<Id<DiskDrive>, IPartitionInfoExs> diskDriveInfoPartitionInfoCOD) {
              DiskDriveInfoPartitionInfoCOD=diskDriveInfoPartitionInfoCOD??throw new ArgumentNullException(nameof(diskDriveInfoPartitionInfoCOD));
          }

          public ConcurrentObservableDictionary<Id<DiskDrive>, IPartitionInfoExs> DiskDriveInfoPartitionInfoCOD { get; set; }

      }

  // ToDo Not sure where this is used, current design would not use a string computerName
      public interface IDiskDriveSpecifier {
          bool Equals(DiskDriveSpecifier other);
          bool Equals(object obj);
          int GetHashCode();
      }

      public class DiskDriveSpecifier : IEquatable<DiskDriveSpecifier>, IDiskDriveSpecifier {
          public DiskDriveSpecifier() :this (string.Empty, null) {}

          public DiskDriveSpecifier(string computerName, int? diskDriveNumber) {
              ComputerName=computerName??throw new ArgumentNullException(nameof(computerName));
              DiskDriveNumber=diskDriveNumber;
          }

          public string ComputerName { get; set; }
          public int? DiskDriveNumber { get; set; }

      }

     *
     * */

