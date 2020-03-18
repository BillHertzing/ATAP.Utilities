using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IPartitionInfoEx
  {
    IEnumerable<string>? DriveLetters { get; }
    TypedGuids.Id<IPartitionInfoEx>? ID { get; }
    TypedGuids.Id<IPartitionInfoEx>? ID2 { get; }
    PartitionFileSystem PartitionFileSystem { get; }
    Information Size { get; }
  }
}
