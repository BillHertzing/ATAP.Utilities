using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software

{
  public interface IComputerSoftwareProgram
  {
    IComputerSoftwareProgramSignil ComputerSoftwareProgramSignil { get; }
    IPhilote<IComputerSoftwareProgram> Philote { get; }
  }
}
