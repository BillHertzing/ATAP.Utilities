using System;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software
{
  [Serializable]
  public class ComputerSoftwareDriver : IComputerSoftwareDriver
  {
    public ComputerSoftwareDriver()
    {
    }

    public ComputerSoftwareDriver(IComputerSoftwareDriverSignil computerSoftwareDriverSignil, IPhilote<IComputerSoftwareDriver>? philote)
    {
      ComputerSoftwareDriverSignil = computerSoftwareDriverSignil ?? throw new ArgumentNullException(nameof(computerSoftwareDriverSignil));
      Philote = philote ;
    }

    public IComputerSoftwareDriverSignil ComputerSoftwareDriverSignil { get; private set; }
    public IPhilote<IComputerSoftwareDriver>? Philote { get; private set; }
  }

}
