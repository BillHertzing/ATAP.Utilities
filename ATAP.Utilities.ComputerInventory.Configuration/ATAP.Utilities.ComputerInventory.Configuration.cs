
using ATAP.Utilities.ComputerInventory.Models;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.ComputerInventory.Configuration
{
	
    public static class DefaultConfigurationSettings
    {
        public static Dictionary<string, ComputerSoftwareProgram> Dcs = new Dictionary<string, ComputerSoftwareProgram>()
        {
            {"PowerShell", new ComputerSoftwareProgram("powershell",
                                                                             @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                                                                             ".",
                                                                             "v5",
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             false,
                                                                             false)
            }
        };
        /*
        public static Dictionary<string, ComputerHardware> Dchw = new Dictionary<string, ComputerHardware>()
        {
            {"ncat016", new ComputerHardware(new CPU[1] {new CPU(CPUMaker.Generic) },new Motherboard(MotherboardMaker.Generic,"ToDo:"),new VideoCard[1] {new VideoCard()})
            }
        };
        */
    }
}
