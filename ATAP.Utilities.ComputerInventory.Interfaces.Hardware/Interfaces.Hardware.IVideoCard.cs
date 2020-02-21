namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IVideoCard
  {
    string BIOSVersion { get; }
    double CoreClock { get; }
    double CoreVoltage { get; }
    string DeviceID { get; }
    bool IsStrapped { get; }
    double MemClock { get; }
    double PowerLimit { get; }
    IVideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics { get; }
  }
}
