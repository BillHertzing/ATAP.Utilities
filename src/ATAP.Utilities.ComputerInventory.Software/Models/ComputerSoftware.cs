using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ATAP.Utilities.Philote;

namespace ATAP.Utilities.ComputerInventory.Software
{



  [Serializable]
  public class ComputerSoftware : IComputerSoftware
  {
    static OperatingSystem OperatingSystemDefault = new OperatingSystem(PlatformID.Win32Windows, new Version("0.0.0"));
    public ComputerSoftware() : this(OperatingSystemDefault, new List<IComputerSoftwareDriver>(), new List<IComputerSoftwareProgram>())
    {
    }
    public ComputerSoftware(OperatingSystem operatingSystem, IEnumerable<IComputerSoftwareDriver> computerSoftwareDrivers, IEnumerable<IComputerSoftwareProgram> computerSoftwarePrograms)
    {
      OperatingSystem = operatingSystem ?? throw new ArgumentNullException(nameof(operatingSystem));
      ComputerSoftwareDrivers = computerSoftwareDrivers ?? throw new ArgumentNullException(nameof(computerSoftwareDrivers));
      ComputerSoftwarePrograms = computerSoftwarePrograms ?? throw new ArgumentNullException(nameof(computerSoftwarePrograms));
    }

    // ToDo implement OS when the bug in dot net core is fixed. this type cannot be serialized by newtonSoft in dot net core v2
    public OperatingSystem OperatingSystem { get; private set; }
    public IEnumerable<IComputerSoftwareDriver> ComputerSoftwareDrivers { get; private set; }
    public IEnumerable<IComputerSoftwareProgram> ComputerSoftwarePrograms { get; private set; }

  }

}
