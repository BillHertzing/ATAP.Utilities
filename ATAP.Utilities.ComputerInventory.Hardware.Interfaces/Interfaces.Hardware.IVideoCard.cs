namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public interface IVideoCard
  {
    string BIOSVersion { get; }
    UnitsNet.Frequency CoreClock { get; }
    UnitsNet.ElectricPotentialDc CoreVoltage { get; }
    string DeviceID { get; }
    bool IsStrapped { get; }
    UnitsNet.Frequency MemClock { get; }
    IPowerConsumption PowerConsumption { get; }
    IVideoCardSignil VideoCardSignil { get; }
  }
}
