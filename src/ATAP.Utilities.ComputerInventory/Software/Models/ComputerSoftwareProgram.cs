using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software
{
  [Serializable]
  public class ComputerSoftwareProgram : IComputerSoftwareProgram
  {

    public ComputerSoftwareProgram(IComputerSoftwareProgramSignil computerSoftwareProgramSignil/*, IPhilote<IComputerSoftwareProgram>? philote*/)
    {
      ComputerSoftwareProgramSignil = computerSoftwareProgramSignil ?? throw new ArgumentNullException(nameof(computerSoftwareProgramSignil));
      // Philote = philote;
    }

    public IComputerSoftwareProgramSignil ComputerSoftwareProgramSignil { get; private set; }
    // TODO: Migrate to new Philote API - old IPhilote<T> no longer exists, use IGuidPhilote<TId> or IIntPhilote<TId>
    // public IPhilote<IComputerSoftwareProgram>? Philote { get; private set; }
  }

}
