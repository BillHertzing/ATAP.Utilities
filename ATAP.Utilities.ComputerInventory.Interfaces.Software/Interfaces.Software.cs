using ATAP.Utilities.ConcurrentObservableCollections;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Software
{

  public interface IComputerSoftwareProgram : IObservable<IComputerSoftwareProgram>
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
    //IDisposable Subscribe(IObserver<IComputerSoftwareProgram> observer);
  }

  public interface IComputerSoftwareDriver : IObservable<IComputerSoftwareDriver>
  {
    string Name { get; }
    string Version { get; }

    bool Equals(IComputerSoftwareDriver other);
    bool Equals(object obj);
    int GetHashCode();
    //IDisposable Subscribe(IObserver<IComputerSoftwareDriver> observer);
  }
  public interface IComputerSoftware
  {
    List<IComputerSoftwareDriver> ComputerSoftwareDrivers { get; }
    List<IComputerSoftwareProgram> ComputerSoftwarePrograms { get; }

    bool Equals(IComputerSoftware other);
    bool Equals(object obj);
    int GetHashCode();
  }


}
