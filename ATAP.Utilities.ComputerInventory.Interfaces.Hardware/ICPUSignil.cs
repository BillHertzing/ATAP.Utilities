using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface ICPUSignil
  {
    Frequency CoreClockNominal { get; }
    ElectricPotentialDc CoreVoltageNominal { get; }
    CPUMaker CPUMaker { get; }
    CPUSocket CPUSocket { get; }
    int NumberOfPhysicalCores { get; }
  }
}
