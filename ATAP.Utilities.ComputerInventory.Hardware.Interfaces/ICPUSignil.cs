using ATAP.Utilities.ComputerInventory.Hardware;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Hardware
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
