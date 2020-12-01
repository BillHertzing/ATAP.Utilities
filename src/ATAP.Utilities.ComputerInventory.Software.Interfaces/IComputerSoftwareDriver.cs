

namespace ATAP.Utilities.ComputerInventory.Software
{
  public interface IComputerSoftwareDriver
  {
    IComputerSoftwareDriverSignil ComputerSoftwareDriverSignil { get; }
    Philote.IPhilote<IComputerSoftwareDriver> Philote { get; }
  }
}
