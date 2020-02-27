namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IVideoCard
  {
    string BIOSVersion { get; }
    UnitsNet.Frequency CoreClock { get; }
    UnitsNet.Units.ElectricPotentialDcUnit CoreVoltage { get; }
    string DeviceID { get; }
    bool IsStrapped { get; }
    UnitsNet.Frequency MemClock { get; }
    UnitsNet.Units.PowerUnit PowerLimit { get; }
    IVideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics { get; }
  }
}
