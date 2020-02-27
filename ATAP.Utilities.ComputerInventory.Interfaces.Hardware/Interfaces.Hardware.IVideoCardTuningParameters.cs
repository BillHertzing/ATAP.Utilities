namespace ATAP.Utilities.ComputerInventory.Configuration.Hardware
{
  public interface IVideoCardTuningParameters
  {
    UnitsNet.Frequency CoreClockDefault { get; }
    UnitsNet.Frequency CoreClockMax { get; }
    UnitsNet.Frequency CoreClockMin { get; }
    UnitsNet.Frequency MemoryClockDefault { get; }
    UnitsNet.Frequency MemoryClockMax { get; }
    UnitsNet.Frequency MemoryClockMin { get; }
    UnitsNet.ElectricPotentialDc VoltageDefault { get; }
    UnitsNet.ElectricPotentialDc VoltageMax { get; }
    UnitsNet.ElectricPotentialDc VoltageMin { get; }
  }
}
