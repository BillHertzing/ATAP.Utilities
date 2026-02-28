namespace ATAP.Utilities.ComputerInventory.Software
{
  public interface IComputerSoftwareProgramSignil
  {
    string APIDiscoveryURL { get; }
    string ConfigFilePath { get; }
    bool HasAPI { get; }
    bool HasConfigurationSettings { get; }
    bool HasERROut { get; }
    bool HasLogFiles { get; }
    bool HasSTDOut { get; }
    string LogFileFnPattern { get; }
    string LogFileFolder { get; }
    string ProcessName { get; }
    string ProcessPath { get; }
    string ProcessStartPath { get; }
    string Version { get; }
  }
}
