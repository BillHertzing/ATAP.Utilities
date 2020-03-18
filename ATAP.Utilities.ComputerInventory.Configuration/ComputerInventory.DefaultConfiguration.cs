
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ConcurrentObservableCollections;
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.ComputerInventory.Configuration
{
	
    public static class DefaultConfiguration
    {
    public static Dictionary<string, string> Production = new Dictionary<string, string>()
    {//{ "PowerShell", Serializer.Serialize(PowerShell) }
    };
      /*
         
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
          */
    }
}
