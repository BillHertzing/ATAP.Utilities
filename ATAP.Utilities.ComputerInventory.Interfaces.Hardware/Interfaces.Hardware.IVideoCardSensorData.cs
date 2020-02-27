namespace ATAP.Utilities.ComputerInventory.Configuration.Hardware
{
  public interface IVideoCardSensorData
  {
    double CoreClock { get; }
    double CoreVoltage { get; }
    double FanRPM { get; }
    double MemClock { get; }
    double PowerConsumption { get; }
    double PowerLimit { get; }
    double Temp { get; }
  }
}
