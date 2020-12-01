using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software
{
  [Serializable]
  public class ComputerSoftwareProgram : IComputerSoftwareProgram
  {

    public ComputerSoftwareProgram(IComputerSoftwareProgramSignil computerSoftwareProgramSignil, IPhilote<IComputerSoftwareProgram>? philote)
    {
      ComputerSoftwareProgramSignil = computerSoftwareProgramSignil ?? throw new ArgumentNullException(nameof(computerSoftwareProgramSignil));
      Philote = philote;
    }

    public IComputerSoftwareProgramSignil ComputerSoftwareProgramSignil { get; private set; }
    public IPhilote<IComputerSoftwareProgram>? Philote { get; private set; }
  }

}
