using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using System;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{
  public class PartitionInfoEx : IPartitionInfoEx
  {
    public PartitionInfoEx()
    {
    }

    public PartitionInfoEx(Id<IPartitionInfoEx>? iD, Id<IPartitionInfoEx>? iD2, IEnumerable<string>? driveLetters, PartitionFileSystem partitionFileSystem, Information size)
    {
      ID = iD;
      ID2 = iD2;
      DriveLetters = driveLetters;
      PartitionFileSystem = partitionFileSystem;
      Size = size;
    }

    public Id<IPartitionInfoEx>? ID { get; private set; }
    public Id<IPartitionInfoEx>? ID2 { get; private set; }
    public IEnumerable<string>? DriveLetters { get; private set; }
    public PartitionFileSystem PartitionFileSystem { get; private set; }
    //public IList<Exception> Exceptions { get; private set; }
    public UnitsNet.Information Size { get; private set; }
  }
    /*
        public interface IPartitionInfoExs {
            ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> PartitionInfoExCOD { get; set; }
        }

        public class PartitionInfoExs : IPartitionInfoExs {
            public PartitionInfoExs() : this (new ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx>()) {}

            public PartitionInfoExs(ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> partitionInfoExCOD) {
                PartitionInfoExCOD=partitionInfoExCOD??throw new ArgumentNullException(nameof(partitionInfoExCOD));
            }

            public ConcurrentObservableDictionary<Id<PartitionInfoEx>, PartitionInfoEx> PartitionInfoExCOD { get; set; }
        }

        public interface IDiskDriveInfoExs {
            ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, DiskDriveInfoEx> DiskDriveCOD { get; set; }
        }

        public class DiskDriveInfoExs : IDiskDriveInfoExs {
            public DiskDriveInfoExs() :this(new ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, DiskDriveInfoEx>()) {}

            public DiskDriveInfoExs(ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, DiskDriveInfoEx> diskDriveInfoExCOD) {
                DiskDriveCOD=diskDriveInfoExCOD??throw new ArgumentNullException(nameof(diskDriveInfoExCOD));
            }

            public ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, DiskDriveInfoEx> DiskDriveCOD { get; set; }
        }



        public interface IDiskDrivePartitionIdentifier {
            ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs> DiskDriveInfoPartitionInfoCOD { get; set; }

            bool Equals(DiskDrivePartitionIdentifier other);
            bool Equals(object obj);
            int GetHashCode();
        }

        public class DiskDrivePartitionIdentifier : IEquatable<DiskDrivePartitionIdentifier>, IDiskDrivePartitionIdentifier {
            public DiskDrivePartitionIdentifier() :this (new ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs>()) {}

            public DiskDrivePartitionIdentifier(ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs> diskDriveInfoPartitionInfoCOD) {
                DiskDriveInfoPartitionInfoCOD=diskDriveInfoPartitionInfoCOD??throw new ArgumentNullException(nameof(diskDriveInfoPartitionInfoCOD));
            }

            public ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs> DiskDriveInfoPartitionInfoCOD { get; set; }

            public override bool Equals(object obj) {
                return Equals(obj as DiskDrivePartitionIdentifier);
            }

            public bool Equals(DiskDrivePartitionIdentifier other) {
                return other!=null&&
                       EqualityComparer<ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs>>.Default.Equals(DiskDriveInfoPartitionInfoCOD, other.DiskDriveInfoPartitionInfoCOD);
            }

            public override int GetHashCode() {
                return -1250799812+EqualityComparer<ConcurrentObservableDictionary<Id<DiskDriveInfoEx>, IPartitionInfoExs>>.Default.GetHashCode(DiskDriveInfoPartitionInfoCOD);
            }

            public static bool operator ==(DiskDrivePartitionIdentifier left, DiskDrivePartitionIdentifier right) {
                return EqualityComparer<DiskDrivePartitionIdentifier>.Default.Equals(left, right);
            }

            public static bool operator !=(DiskDrivePartitionIdentifier left, DiskDrivePartitionIdentifier right) {
                return !(left==right);
            }
        }

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

            public override bool Equals(object obj) {
                return Equals(obj as DiskDriveSpecifier);
            }

            public bool Equals(DiskDriveSpecifier other) {
                return other!=null&&
                       ComputerName==other.ComputerName&&
                       EqualityComparer<int?>.Default.Equals(DiskDriveNumber, other.DiskDriveNumber);
            }

            public override int GetHashCode() {
                var hashCode = 748249881;
                hashCode=hashCode*-1521134295+EqualityComparer<string>.Default.GetHashCode(ComputerName);
                hashCode=hashCode*-1521134295+EqualityComparer<int?>.Default.GetHashCode(DiskDriveNumber);
                return hashCode;
            }

            public static bool operator ==(DiskDriveSpecifier left, DiskDriveSpecifier right) {
                return EqualityComparer<DiskDriveSpecifier>.Default.Equals(left, right);
            }

            public static bool operator !=(DiskDriveSpecifier left, DiskDriveSpecifier right) {
                return !(left==right);
            }
        }

       *
       * */
  }
