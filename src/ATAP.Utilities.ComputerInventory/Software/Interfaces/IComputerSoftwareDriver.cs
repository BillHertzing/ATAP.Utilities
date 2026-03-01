

namespace ATAP.Utilities.ComputerInventory.Software
{
  public interface IComputerSoftwareDriver
  {
    IComputerSoftwareDriverSignil ComputerSoftwareDriverSignil { get; }
    // TODO: Migrate to new Philote API - old IPhilote<T> no longer exists, use IGuidPhilote<TId> or IIntPhilote<TId>
    // Philote.IPhilote<IComputerSoftwareDriver> Philote { get; }
  }
}
