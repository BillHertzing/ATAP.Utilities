using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using System;
using System.Collections.Generic;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{
  [Serializable]
  public class DiskDriveSignil : IDiskDriveSignil, IEquatable<DiskDriveSignil>
  {
    public DiskDriveSignil()
    {
    }

    public DiskDriveSignil(DiskDriveMaker diskDriveMaker, DiskDriveType diskDriveType, Information informationSize)
    {
      DiskDriveMaker = diskDriveMaker;
      DiskDriveType = diskDriveType;
      InformationSize = informationSize;
    }

    public DiskDriveMaker DiskDriveMaker { get; private set; }
    public DiskDriveType DiskDriveType { get; private set; }
    public UnitsNet.Information InformationSize { get; private set; }

    public override bool Equals(object obj)
    {
      return Equals(obj as DiskDriveSignil);
    }

    public bool Equals(DiskDriveSignil other)
    {
      return other != null &&
             DiskDriveMaker == other.DiskDriveMaker &&
             DiskDriveType == other.DiskDriveType &&
             InformationSize.Equals(other.InformationSize);
    }

    public override int GetHashCode()
    {
      var hashCode = -2077317876;
      hashCode = hashCode * -1521134295 + DiskDriveMaker.GetHashCode();
      hashCode = hashCode * -1521134295 + DiskDriveType.GetHashCode();
      hashCode = hashCode * -1521134295 + InformationSize.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(DiskDriveSignil left, DiskDriveSignil right)
    {
      return EqualityComparer<DiskDriveSignil>.Default.Equals(left, right);
    }

    public static bool operator !=(DiskDriveSignil left, DiskDriveSignil right)
    {
      return !(left == right);
    }
  }


}
