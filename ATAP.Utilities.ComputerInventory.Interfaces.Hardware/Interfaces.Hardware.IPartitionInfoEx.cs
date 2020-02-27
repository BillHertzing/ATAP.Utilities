using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.TypedGuids;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IPartitionInfoEx
  {
    Id<IPartitionInfoEx> PartitionId { get; set; }

    IEnumerable<string> DriveLetters { get; set; }
    IList<Exception> Exceptions { get; set; }
    Id<IPartitionInfoEx> PartitionDbId { get; set; }
    PartitionFileSystem PartitionFileSystem { get; set; }
    long? Size { get; set; }
  }
 
}
