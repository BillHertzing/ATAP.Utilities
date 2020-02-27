using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.TypedGuids;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IDiskDriveInfoExs
  {
    ConcurrentObservableDictionary<Id<IDiskDriveInfoEx>, IDiskDriveInfoEx> DiskDriveInfoExCOD { get; set; }
  }
 
}
