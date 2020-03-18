
using ATAP.Utilities.Philote;
using System;

namespace ATAP.Utilities.ComputerInventory.Hardware
{

  [Serializable]
  public class CPU : ICPU
  {
    public CPU()
    {
      CPUSignil = new CPUSignil();
    }

    public CPU(ICPUSignil cPUSignil, IPhilote<ICPU>? philote)
    {
      CPUSignil = cPUSignil ?? throw new ArgumentNullException(nameof(cPUSignil));
      Philote = philote;
    }

    public CPU(ICPUSignil cPUSignil)
    {
      CPUSignil = cPUSignil ?? throw new ArgumentNullException(nameof(cPUSignil));
      Philote = null;
    }
    public ICPUSignil CPUSignil { get; private set; }
    public IPhilote<ICPU>? Philote { get; private set; }

  }
}
