using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

namespace ATAP.Utilities.ComputerInventory.Configuration.Software
{

  [Serializable]
  public class ComputerSoftwareProgram : IComputerSoftwareProgram
  {
    public ComputerSoftwareProgram()
    {
    }

    public ComputerSoftwareProgram(string processName, string processPath, string version, string processStartPath, bool hasConfigurationSettings,  ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasSTDOut, bool hasERROut, bool hasAPI, string aPIDiscoveryURL, bool hasLogFiles, string logFileFolder, string logFileFnPattern )
    {
      ProcessName = processName ?? throw new ArgumentNullException(nameof(processName));
      ProcessPath = processPath ?? throw new ArgumentNullException(nameof(processPath));
      Version = version ?? throw new ArgumentNullException(nameof(version));
      ProcessStartPath = processStartPath ?? throw new ArgumentNullException(nameof(processStartPath));
      ConfigFilePath = configFilePath ?? throw new ArgumentNullException(nameof(configFilePath));
      ConfigurationSettings = configurationSettings ?? throw new ArgumentNullException(nameof(configurationSettings));
      HasAPI = hasAPI;
      APIDiscoveryURL = aPIDiscoveryURL ?? throw new ArgumentNullException(nameof(aPIDiscoveryURL));
      HasConfigurationSettings = hasConfigurationSettings;
      HasERROut = hasERROut;
      HasLogFiles = hasLogFiles;
      HasSTDOut = hasSTDOut;
      LogFileFnPattern = logFileFnPattern ?? throw new ArgumentNullException(nameof(logFileFnPattern));
      LogFileFolder = logFileFolder ?? throw new ArgumentNullException(nameof(logFileFolder));
    }

    public string APIDiscoveryURL { get; }
    public string ConfigFilePath { get; }
    public ConcurrentObservableDictionary<string, string> ConfigurationSettings { get; }
    public bool HasAPI { get; }
    public bool HasConfigurationSettings { get; }
    public bool HasERROut { get; }
    public bool HasLogFiles { get; }
    public bool HasSTDOut { get; }
    public string LogFileFnPattern { get; }
    public string LogFileFolder { get; }
    //ComputerSW Kind{ get; }
    public string ProcessName { get; }
    public string ProcessPath { get; }
    public string ProcessStartPath { get; }
    public string Version { get; }

  }


  [Serializable]
  public class ComputerSoftwareDriver : IEquatable<IComputerSoftwareDriver>, IComputerSoftwareDriver
  {
    public ComputerSoftwareDriver()
    {
    }

    public ComputerSoftwareDriver(string name, string version)
    {
      Name = name ?? throw new ArgumentNullException(nameof(name));
      Version = version ?? throw new ArgumentNullException(nameof(version));
    }

    public string Name { get; }
    public string Version { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerSoftwareDriver);
    }

    public bool Equals(IComputerSoftwareDriver other)
    {
      return other != null &&
             Name == other.Name &&
             Version == other.Version;
    }

    public override int GetHashCode()
    {
      var hashCode = 2112831277;
      hashCode = hashCode * -1521134295 + EqualityComparer<string>.Default.GetHashCode(Name);
      hashCode = hashCode * -1521134295 + EqualityComparer<string>.Default.GetHashCode(Version);
      return hashCode;
    }

    public static bool operator ==(ComputerSoftwareDriver left, ComputerSoftwareDriver right)
    {
      return EqualityComparer<ComputerSoftwareDriver>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerSoftwareDriver left, ComputerSoftwareDriver right)
    {
      return !(left == right);
    }
  }



  [Serializable]
  public class ComputerSoftware : IComputerSoftware, IEquatable<ComputerSoftware>
  {
    public ComputerSoftware()
    {
    }

    public ComputerSoftware(OperatingSystem operatingSystem, List<IComputerSoftwareDriver> computerSoftwareDrivers, List<IComputerSoftwareProgram> computerSoftwarePrograms)
    {
      OperatingSystem = operatingSystem ?? throw new ArgumentNullException(nameof(operatingSystem));
      ComputerSoftwareDrivers = computerSoftwareDrivers ?? throw new ArgumentNullException(nameof(computerSoftwareDrivers));
      ComputerSoftwarePrograms = computerSoftwarePrograms ?? throw new ArgumentNullException(nameof(computerSoftwarePrograms));
    }



    // ToDo implement OS when the bug in dot net core is fixed. this type cannot be serialized by newtonSoft in dot net core v2
    public OperatingSystem OperatingSystem { get; }
    public List<IComputerSoftwareDriver> ComputerSoftwareDrivers { get; }
    public List<IComputerSoftwareProgram> ComputerSoftwarePrograms { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerSoftware);
    }

    public bool Equals(ComputerSoftware other)
    {
      return other != null &&
             EqualityComparer<OperatingSystem>.Default.Equals(OperatingSystem, other.OperatingSystem) &&
             EqualityComparer<List<IComputerSoftwareDriver>>.Default.Equals(ComputerSoftwareDrivers, other.ComputerSoftwareDrivers) &&
             EqualityComparer<List<IComputerSoftwareProgram>>.Default.Equals(ComputerSoftwarePrograms, other.ComputerSoftwarePrograms);
    }

    public override int GetHashCode()
    {
      var hashCode = -2024901995;
      hashCode = hashCode * -1521134295 + EqualityComparer<OperatingSystem>.Default.GetHashCode(OperatingSystem);
      hashCode = hashCode * -1521134295 + EqualityComparer<List<IComputerSoftwareDriver>>.Default.GetHashCode(ComputerSoftwareDrivers);
      hashCode = hashCode * -1521134295 + EqualityComparer<List<IComputerSoftwareProgram>>.Default.GetHashCode(ComputerSoftwarePrograms);
      return hashCode;
    }

    public static bool operator ==(ComputerSoftware left, ComputerSoftware right)
    {
      return EqualityComparer<ComputerSoftware>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerSoftware left, ComputerSoftware right)
    {
      return !(left == right);
    }
  }

}
