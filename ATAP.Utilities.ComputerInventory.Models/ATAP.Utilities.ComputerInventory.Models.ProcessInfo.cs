using System;
using Medallion.Shell;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;

namespace ATAP.Utilities.ComputerInventory.Models
{

      public class ComputerProcess
    {
        readonly object[] arguments;
        Command cmd;
        readonly IComputerSoftwareProgram computerSoftwareProgram;

        public ComputerProcess(IComputerSoftwareProgram computerSoftwareProgram, params object[] arguments)
        {
            this.computerSoftwareProgram = computerSoftwareProgram;
            this.arguments = arguments;
        }

        
        public object[] Arguments => arguments;
        public IComputerSoftwareProgram ComputerSoftwareProgram => computerSoftwareProgram;

        public Command Cmd { get => cmd; set => cmd = value; }
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
