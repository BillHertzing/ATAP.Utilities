using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software

{
  public interface IComputerSoftwareProgram
  {
    IComputerSoftwareProgramSignil ComputerSoftwareProgramSignil { get; }
    // TODO: Migrate to new Philote API - old IPhilote<T> no longer exists, use IGuidPhilote<TId> or IIntPhilote<TId>
    // IPhilote<IComputerSoftwareProgram> Philote { get; }
  }
}
