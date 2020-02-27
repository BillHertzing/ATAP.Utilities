using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.TypedGuids;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IPartitionInfoExs
  {
    ConcurrentObservableDictionary<Id<IPartitionInfoEx>, IPartitionInfoEx> PartitionInfoExCOD { get; set; }
  }
 
}
