using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.TypedGuids;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDrivePartitionIdentifier
  {
    ConcurrentObservableDictionary<Id<IDiskDriveInfoEx>, IPartitionInfoExs> DiskDriveInfoPartitionInfoCOD { get; set; }

  }
 
}
