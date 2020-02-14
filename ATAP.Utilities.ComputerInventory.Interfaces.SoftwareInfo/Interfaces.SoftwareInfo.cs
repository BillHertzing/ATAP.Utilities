using ATAP.Utilities.ConcurrentObservableCollections;
using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.SoftwareInfo
{
  public interface IComputerSoftwareProgram
  {
    string ConfigFilePath { get; }
    ConcurrentObservableDictionary<string, string> ConfigurationSettings { get; }
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
