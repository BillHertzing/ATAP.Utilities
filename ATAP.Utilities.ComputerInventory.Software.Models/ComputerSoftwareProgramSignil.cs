using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Software
{
  [Serializable]
  public class ComputerSoftwareProgramSignil : IComputerSoftwareProgramSignil
  {

    /*
    public ComputerSoftwareProgramSignil(IComputerSoftwareProgramSignil other) 
    {
      ProcessName = other.ProcessName;
      ProcessPath = other.ProcessPath;
      ProcessStartPath = other.ProcessStartPath;
      Version = other.Version;
      HasSTDOut = other.HasSTDOut;
      HasERROut = other.HasERROut;
      HasLogFiles = other.HasLogFiles;
      LogFileFolder = other.LogFileFolder;
      LogFileFnPattern = other.LogFileFnPattern;
      HasAPI = other.HasAPI;
      APIDiscoveryURL = other.APIDiscoveryURL;
      HasConfigurationSettings = other.HasConfigurationSettings;
      ConfigFilePath = other.ConfigFilePath;
    }
    */
    public ComputerSoftwareProgramSignil(string processName, string processPath, string processStartPath, string version, bool hasSTDOut, bool hasERROut, bool hasLogFiles, string? logFileFolder, string? logFileFnPattern, bool hasAPI, string? aPIDiscoveryURL, bool hasConfigurationSettings, string? configFilePath)
    {
      ProcessName = processName ?? throw new ArgumentNullException(nameof(processName));
      ProcessPath = processPath ?? throw new ArgumentNullException(nameof(processPath));
      ProcessStartPath = processStartPath ?? throw new ArgumentNullException(nameof(processStartPath));
      Version = version ?? throw new ArgumentNullException(nameof(version));
      HasSTDOut = hasSTDOut;
      HasERROut = hasERROut;
      HasLogFiles = hasLogFiles;
      LogFileFolder = logFileFolder;
      LogFileFnPattern = logFileFnPattern;
      HasAPI = hasAPI;
      APIDiscoveryURL = aPIDiscoveryURL;
      HasConfigurationSettings = hasConfigurationSettings;
      ConfigFilePath = configFilePath;
    }

    public string ProcessName { get; private set; }
    public string ProcessPath { get; private set; }
    public string ProcessStartPath { get; private set; }
    public string Version { get; private set; }
    public bool HasSTDOut { get; private set; }
    public bool HasERROut { get; private set; }
    public bool HasLogFiles { get; private set; }
    public string? LogFileFolder { get; private set; }
    public string? LogFileFnPattern { get; private set; }
    public bool HasAPI { get; private set; }
    public string? APIDiscoveryURL { get; private set; }
    public bool HasConfigurationSettings { get; private set; }
    public string? ConfigFilePath { get; private set; }
    // public ConcurrentObservableDictionary<string, string> ConfigurationSettings { get; private set; }
    //ComputerSW Kind{ get; }
  }

  public static class DefaultConfiguration
  {
    public static IDictionary<string, IComputerSoftwareProgramSignil> Production = new Dictionary<string, IComputerSoftwareProgramSignil>() {
        { "Generic", new ComputerSoftwareProgramSignil("Generic", @".", ".", "0.0.0", true, true, true, ".", ".log", false, null, false, null)},
        { "PowerShell", new ComputerSoftwareProgramSignil("powershell", @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe", ".", "v5", true, true, true, ".", ".log", false, null, false, null)},
        { "dotnet", new ComputerSoftwareProgramSignil("dotnet", @"C:\Windows\dotnet.exe", ".", "v16", true, true, true, ".", ".log", false, null, false, null)},
        { "EthDCRMiner",  new ComputerSoftwareProgramSignil("EthDCRMiner",@"C:\",".","v1",false,false,false,".",".log", false, null, false, null)}
      };
  }
}

