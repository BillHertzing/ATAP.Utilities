using ATAP.Utilities.ComputerInventory.Configuration.Software;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Extensions
{
  public static partial class Extensions
  {
    public static ComputerSoftware InventoryThisComputer(this ComputerSoftware computerSoftware)
    {
      throw new NotImplementedException();
    }

    //ToDo: Implement writing a ComputerSoftware object to a set of Configuration Settings
    public static Dictionary<string, string> ToConfigurationSettings(this ComputerSoftware computerSoftware)
    {
      throw new NotImplementedException();
    }

    //ToDo: Implement creating a ComputerSoftware object from a set of Configuration Settings
    public static bool FromConfigurationSettings(Dictionary<string, string> configurationSettings, out ComputerSoftware computerSoftware)
    {
      throw new NotImplementedException();
    }


    //ToDo: Implement writing a ComputerSoftwareProgram object to a set of Configuration Settings
    public static Dictionary<string, string> ToConfigurationSettings(this ComputerSoftwareProgram computerSoftwareProgram)
      {
        throw new NotImplementedException();
      }

    //ToDo: Implement creating a ComputerSoftwareProgram object from a set of Configuration Settings
    public static bool FromConfigurationSettings(Dictionary<string, string> configurationSettings, out ComputerSoftwareProgram computerSoftwareProgram)
      {
        throw new NotImplementedException();
      }

    }


  }
