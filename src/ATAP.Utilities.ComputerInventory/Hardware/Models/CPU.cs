
using ATAP.Utilities.Philote;
using ATAP.Utilities.StronglyTypedId;
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

    public CPU(ICPUSignil cPUSignil, IGuidPhilote<GuidStronglyTypedId>? philote)
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
    public IGuidPhilote<GuidStronglyTypedId>? Philote { get; private set; }

  }
}
