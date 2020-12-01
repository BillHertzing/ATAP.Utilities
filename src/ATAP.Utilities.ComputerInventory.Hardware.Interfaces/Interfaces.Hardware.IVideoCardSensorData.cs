namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IVideoCardSensorData
  {
    UnitsNet.Units.FrequencyUnit CoreClock { get; }
    UnitsNet.Units.ElectricPotentialDcUnit CoreVoltage { get; }
    double FanRPM { get; }
    UnitsNet.Units.FrequencyUnit MemClock { get; }
    double PowerConsumption { get; }
    double PowerLimit { get; }
    UnitsNet.Units.TemperatureUnit Temp { get; }
  }
}
