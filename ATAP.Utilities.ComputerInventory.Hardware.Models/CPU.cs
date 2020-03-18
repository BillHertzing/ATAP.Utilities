
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{


  [Serializable]
  public class CPU : ICPU, IEquatable<CPU>
  {
    public CPU()
    {
    }

    public CPU(ICPUSignil cPUSignil, Id<ICPU>? iD, ITimeBlock? timeBlock)
    {
      CPUSignil = cPUSignil ?? throw new ArgumentNullException(nameof(cPUSignil));
      ID = iD;
      TimeBlock = timeBlock;
    }

    public ICPUSignil CPUSignil { get; private set; }
    public Id<ICPU>? ID { get; private set; }
    public ITimeBlock? TimeBlock { get; private set; }

    public override bool Equals(object obj)
    {
      return Equals(obj as CPU);
    }

    public bool Equals(CPU other)
    {
      return other != null &&
             EqualityComparer<ICPUSignil>.Default.Equals(CPUSignil, other.CPUSignil) &&
             EqualityComparer<Id<ICPU>?>.Default.Equals(ID, other.ID) &&
             EqualityComparer<ITimeBlock>.Default.Equals(TimeBlock, other.TimeBlock);
    }

    public override int GetHashCode()
    {
      var hashCode = -1383627126;
      hashCode = hashCode * -1521134295 + EqualityComparer<ICPUSignil>.Default.GetHashCode(CPUSignil);
      hashCode = hashCode * -1521134295 + ID.GetHashCode();
      hashCode = hashCode * -1521134295 + EqualityComparer<ITimeBlock>.Default.GetHashCode(TimeBlock);
      return hashCode;
    }

    public static bool operator ==(CPU left, CPU right)
    {
      return EqualityComparer<CPU>.Default.Equals(left, right);
    }

    public static bool operator !=(CPU left, CPU right)
    {
      return !(left == right);
    }
  }
}
