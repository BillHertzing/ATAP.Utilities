using ATAP.Utilities.Philote;
using ATAP.Utilities.StronglyTypedId;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public interface IPartitionInfoEx
  {
    PartitionFileSystem PartitionFileSystem { get; }
    Information Size { get; }
    IEnumerable<char>? DriveLetters { get; }
    IGuidPhilote<GuidStronglyTypedId>? Philote { get; }
  }

}
