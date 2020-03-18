using System;
using System.Collections.Generic;
using UnitsNet;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  [Serializable]
  public class CPUSignil : ICPUSignil, IEquatable<CPUSignil>
  {
    public CPUSignil()
    {
    }

    public CPUSignil(CPUMaker cPUMaker, CPUSocket cPUSocket, int numberOfPhysicalCores, Frequency coreClockNominal, ElectricPotentialDc coreVoltageNominal)
    {
      CPUMaker = cPUMaker;
      CPUSocket = cPUSocket;
      NumberOfPhysicalCores = numberOfPhysicalCores;
      CoreClockNominal = coreClockNominal;
      CoreVoltageNominal = coreVoltageNominal;
    }

    public CPUMaker CPUMaker { get; private set; }
    public CPUSocket CPUSocket { get; private set; }

    public int NumberOfPhysicalCores { get; private set; }
    public Frequency CoreClockNominal { get; private set; }
    public ElectricPotentialDc CoreVoltageNominal { get; private set; }

    public override bool Equals(object obj)
    {
      return Equals(obj as CPUSignil);
    }

    public bool Equals(CPUSignil other)
    {
      return other != null &&
             CPUMaker == other.CPUMaker &&
             CPUSocket == other.CPUSocket &&
             NumberOfPhysicalCores == other.NumberOfPhysicalCores &&
             CoreClockNominal == other.CoreClockNominal &&
             CoreVoltageNominal.Equals(other.CoreVoltageNominal);
    }

    public override int GetHashCode()
    {
      var hashCode = -1715037593;
      hashCode = hashCode * -1521134295 + CPUMaker.GetHashCode();
      hashCode = hashCode * -1521134295 + CPUSocket.GetHashCode();
      hashCode = hashCode * -1521134295 + NumberOfPhysicalCores.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreClockNominal.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreVoltageNominal.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(CPUSignil left, CPUSignil right)
    {
      return EqualityComparer<CPUSignil>.Default.Equals(left, right);
    }

    public static bool operator !=(CPUSignil left, CPUSignil right)
    {
      return !(left == right);
    }
  }


}
