using System;
using System.Collections.Generic;

using System.Runtime.Serialization;
using ATAP.Utilities.ComputerInventory.Enumerations;
using Swordfish.NET.Collections;

namespace ATAP.Utilities.ComputerInventory.Models
{
  public class ComputerInventory
  {
    readonly ComputerHardware computerHardware;
    readonly ComputerSoftware computerSoftware;
    ComputerProcesses computerProcesses;

    public ComputerHardware ComputerHardware => computerHardware;

    public ComputerSoftware ComputerSoftware => computerSoftware;

    public ComputerProcesses ComputerProcesses { get => computerProcesses; set => computerProcesses = value; }

    public ComputerInventory(ComputerHardware computerHardware, ComputerSoftware computerSoftware, ComputerProcesses computerProcesses)
    {
      this.computerHardware = computerHardware ?? throw new ArgumentNullException(nameof(computerHardware));
      this.computerSoftware = computerSoftware ?? throw new ArgumentNullException(nameof(computerSoftware));
      this.computerProcesses = computerProcesses ?? throw new ArgumentNullException(nameof(computerProcesses));
    }
  }

}

