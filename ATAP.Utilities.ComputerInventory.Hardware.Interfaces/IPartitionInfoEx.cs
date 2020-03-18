using ATAP.Utilities.Philote;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public interface IPartitionInfoEx
  {
    PartitionFileSystem PartitionFileSystem { get; }
    Information Size { get; }
    IEnumerable<char>? DriveLetters { get; }
    IPhilote<IPartitionInfoEx>? Philote { get; }
  }

}
