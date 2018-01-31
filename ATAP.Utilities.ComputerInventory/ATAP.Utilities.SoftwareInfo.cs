using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.ComputerInventory
{
    public abstract class ComputerSoftware
    {
        //ComputerSW kind;
        string processName;
        string processPath;
        string processStartPath;
        private string version;

        public string ProcessName { get => processName; }
        public string ProcessPath { get => processPath; }
        public string ProcessStartPath { get => processStartPath; }
        public string Version { get => version;  }
    }

    public class ComputerSoftwareKnown: ComputerSoftware { }

    public class ComputerSoftwareInventory : ComputerSoftwareKnown { }

    public class ComputerSoftwareConfigured : ComputerSoftwareInventory { }

}
