
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ConcurrentObservableCollections;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.ComputerInventory.Configuration
{
	
    public static class DefaultConfigurationSettings
    {
        public static Dictionary<string, IComputerSoftwareProgram> Dcs = new Dictionary<string, IComputerSoftwareProgram>()
        {
            {"PowerShell", new ComputerSoftwareProgram(
              "powershell",
              @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
              "v5",
              ".",
              false,
              new ConcurrentObservableDictionary<string, string>(),
              ".",
              true,
              true,
              false,
              "",
              false,
              "*.log",
               ".")
            }
        };

        public static Dictionary<string, IComputerHardware> Dchw = new Dictionary<string, IComputerHardware>()
        {
            {"generic", new ComputerHardware(
              new CPU[1] {new CPU(CPUMaker.Generic) },
              true,
              true,
              true,
              true,
              new MainBoard(
                MainBoardMaker.Generic,
                CPUSocket.Generic),
              new TimeBlock(),
              new VideoCard[1] {new VideoCard() }

            )
            }
        };
        
    }
}
