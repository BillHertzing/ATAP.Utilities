using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.TypedGuids;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDrivePartitionIdentifier
  {
    ConcurrentObservableDictionary<Id<IDiskDrive>, IPartitionInfoExs> DiskDriveToPartitionInfoCOD { get; set; }

  }
 
}
