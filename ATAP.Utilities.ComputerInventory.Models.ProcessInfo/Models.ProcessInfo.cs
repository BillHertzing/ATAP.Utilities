using System;
using Medallion.Shell;
using System.Collections.Generic;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;

namespace ATAP.Utilities.ComputerInventory.Models.ProcessInfo
{
  public class ComputerProcess : IEquatable<ComputerProcess>, IComputerProcess
  {
    public ComputerProcess()
    {
    }

    public ComputerProcess(object[] arguments, Command command, IComputerSoftwareProgram computerSoftwareProgram)
    {
      Arguments = arguments ?? throw new ArgumentNullException(nameof(arguments));
      Command = command ?? throw new ArgumentNullException(nameof(command));
      ComputerSoftwareProgram = computerSoftwareProgram ?? throw new ArgumentNullException(nameof(computerSoftwareProgram));
    }

    object[] Arguments { get; }
    Command Command { get; }
    IComputerSoftwareProgram ComputerSoftwareProgram { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerProcess);
    }

    public bool Equals(ComputerProcess other)
    {
      return other != null &&
             EqualityComparer<object[]>.Default.Equals(Arguments, other.Arguments) &&
             EqualityComparer<Command>.Default.Equals(Command, other.Command) &&
             EqualityComparer<IComputerSoftwareProgram>.Default.Equals(ComputerSoftwareProgram, other.ComputerSoftwareProgram);
    }

    public override int GetHashCode()
    {
      var hashCode = 1615262500;
      hashCode = hashCode * -1521134295 + EqualityComparer<object[]>.Default.GetHashCode(Arguments);
      hashCode = hashCode * -1521134295 + EqualityComparer<Command>.Default.GetHashCode(Command);
      hashCode = hashCode * -1521134295 + EqualityComparer<IComputerSoftwareProgram>.Default.GetHashCode(ComputerSoftwareProgram);
      return hashCode;
    }

    public static bool operator ==(ComputerProcess left, ComputerProcess right)
    {
      return EqualityComparer<ComputerProcess>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerProcess left, ComputerProcess right)
    {
      return !(left == right);
    }
  }


  public class ComputerProcesses
{
  public ConcurrentObservableDictionary<int, ComputerProcess> computerProcessDictionary;

  public ComputerProcesses() : this(new ConcurrentObservableDictionary<int, ComputerProcess>())
  {
  }
  public ComputerProcesses(ConcurrentObservableDictionary<int, ComputerProcess> computerProcessDictionary)
  {
    this.computerProcessDictionary = computerProcessDictionary;
  }

  public ConcurrentObservableDictionary<int, ComputerProcess> ComputerProcessDictionary { get => computerProcessDictionary; set => computerProcessDictionary = value; }

}
}
