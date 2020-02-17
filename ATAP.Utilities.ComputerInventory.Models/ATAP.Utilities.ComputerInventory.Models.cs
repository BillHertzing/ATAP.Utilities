using System;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using ATAP.Utilities.ComputerInventory.Models.Software;
using ATAP.Utilities.ComputerInventory.Models.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Models
{
  public class ComputerInventory : IEquatable<ComputerInventory>, IComputerInventory
  {
    public ComputerInventory()
    {
    }

    public ComputerInventory(IComputerHardware computerHardware, IComputerSoftware computerSoftware, IComputerProcesses computerProcesses)
    {
      ComputerHardware = computerHardware ?? throw new ArgumentNullException(nameof(computerHardware));
      ComputerSoftware = computerSoftware ?? throw new ArgumentNullException(nameof(computerSoftware));
      ComputerProcesses = computerProcesses ?? throw new ArgumentNullException(nameof(computerProcesses));
    }

    public IComputerHardware ComputerHardware { get; }
    public IComputerSoftware ComputerSoftware { get; }
    public IComputerProcesses ComputerProcesses { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerInventory);
    }

    public bool Equals(ComputerInventory other)
    {
      return other != null &&
             EqualityComparer<ComputerHardware>.Default.Equals(ComputerHardware, other.ComputerHardware) &&
             EqualityComparer<ComputerSoftware>.Default.Equals(ComputerSoftware, other.ComputerSoftware) &&
             EqualityComparer<ComputerProcesses>.Default.Equals(ComputerProcesses, other.ComputerProcesses);
    }

    public override int GetHashCode()
    {
      var hashCode = 1714258590;
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerHardware>.Default.GetHashCode(ComputerHardware);
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerSoftware>.Default.GetHashCode(ComputerSoftware);
      hashCode = hashCode * -1521134295 + EqualityComparer<ComputerProcesses>.Default.GetHashCode(ComputerProcesses);
      return hashCode;
    }

    public static bool operator ==(ComputerInventory left, ComputerInventory right)
    {
      return EqualityComparer<ComputerInventory>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerInventory left, ComputerInventory right)
    {
      return !(left == right);
    }
  }
}
