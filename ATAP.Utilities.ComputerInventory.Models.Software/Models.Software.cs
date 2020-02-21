using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

namespace ATAP.Utilities.ComputerInventory.Models.Software
{
 

    [Serializable]
    public class ComputerSoftwareProgram : IComputerSoftwareProgram
    {
        readonly string configFilePath;
        readonly ConcurrentObservableDictionary<string, string> configurationSettings;
        readonly bool hasAPI;
        readonly bool hasConfigurationSettings;
        readonly bool hasERROut;
        readonly bool hasLogFiles;
        readonly bool hasSTDOut;
        readonly string logFileFnPattern;
        readonly string logFileFolder;
        //ComputerSW kind;
        readonly string processName;
        readonly string processPath;
        readonly string processStartPath;
        readonly string version;

        public ComputerSoftwareProgram(string processName, string processPath, string processStartPath, string version, bool hasConfigurationSettings, ConcurrentObservableDictionary<string, string> configurationSettings, string configFilePath, bool hasLogFiles, string logFileFolder, string logFileFnPattern, bool hasAPI, bool hasSTDOut, bool hasERROut)
        {
            this.processName = processName;
            this.processPath = processPath;
            this.processStartPath = processStartPath;
            this.version = version;
            this.hasConfigurationSettings = hasConfigurationSettings;
            this.configurationSettings = configurationSettings;
            this.configFilePath = configFilePath;
            this.hasLogFiles = hasLogFiles;
            this.logFileFolder = logFileFolder;
            this.logFileFnPattern = logFileFnPattern;
            this.hasAPI = hasAPI;
            this.hasSTDOut = hasSTDOut;
            this.hasERROut = hasERROut;
        }

        public string ConfigFilePath => configFilePath;

        public ConcurrentObservableDictionary<string, string> ConfigurationSettings => configurationSettings;

        public bool HasAPI => hasAPI;

        public bool HasConfigurationSettings => hasConfigurationSettings;

        public bool HasERROut => hasERROut;

        public bool HasLogFiles => hasLogFiles;

        public bool HasSTDOut => hasSTDOut;

        public string LogFileFnPattern => logFileFnPattern;

        public string LogFileFolder => logFileFolder;

        public string ProcessName => processName;

        public string ProcessPath => processPath;

        public string ProcessStartPath => processStartPath;

        public string Version => version;
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
  public class ComputerSoftware : IEquatable<IComputerSoftware>, IComputerSoftware
  {
    public ComputerSoftware()
    {
    }

    public ComputerSoftware(List<IComputerSoftwareDriver> computerSoftwareDrivers, List<IComputerSoftwareProgram> computerSoftwarePrograms)
    {
      ComputerSoftwareDrivers = computerSoftwareDrivers ?? throw new ArgumentNullException(nameof(computerSoftwareDrivers));
      ComputerSoftwarePrograms = computerSoftwarePrograms ?? throw new ArgumentNullException(nameof(computerSoftwarePrograms));
    }

    // ToDo implement OS when the bug in dot net core is fixed. this type cannot be serialized by newtonSoft in dot net core v2
    //readonly OperatingSystem oS;
    public List<IComputerSoftwareDriver> ComputerSoftwareDrivers { get; }
    public List<IComputerSoftwareProgram> ComputerSoftwarePrograms { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerSoftware);
    }

    public bool Equals(IComputerSoftware other)
    {
      return other != null &&
             EqualityComparer<List<IComputerSoftwareDriver>>.Default.Equals(ComputerSoftwareDrivers, other.ComputerSoftwareDrivers) &&
             EqualityComparer<List<IComputerSoftwareProgram>>.Default.Equals(ComputerSoftwarePrograms, other.ComputerSoftwarePrograms);
    }

    public override int GetHashCode()
    {
      var hashCode = 398348444;
      //ToDo: Fix This
      // hashCode = hashCode * -1521134295 + EqualityComparer<List<ComputerSoftwareDriver>>.Default.GetHashCode(IComputerSoftwareDrivers);
      //hashCode = hashCode * -1521134295 + EqualityComparer<List<ComputerSoftwareProgram>>.Default.GetHashCode(IComputerSoftwarePrograms);
      //return hashCode;
      throw new NotImplementedException("trying to get a hash code for two collections");
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
