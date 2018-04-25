using System;
using Medallion.Shell;
using Swordfish.NET.Collections;

namespace ATAP.Utilities.ComputerInventory
{
    public class ComputerProcesses
    {
        public ConcurrentObservableDictionary<int, ComputerProcess> computerProcessDictionary;

        public ComputerProcesses() : this(new ConcurrentObservableDictionary<int, ComputerProcess>()) {
        }
        public ComputerProcesses(ConcurrentObservableDictionary<int, ComputerProcess> computerProcessDictionary)
        {
            this.computerProcessDictionary = computerProcessDictionary;
        }

        public ConcurrentObservableDictionary<int, ComputerProcess> ComputerProcessDictionary { get => computerProcessDictionary; set => computerProcessDictionary = value; }

        public int Start(IComputerSoftwareProgram computerSoftwareProgram, params object[] arguments)
        {
            ComputerProcess computerProcess = new ComputerProcess(computerSoftwareProgram, arguments);
            int pid = computerProcess.Start();
            computerProcessDictionary.Add(pid, computerProcess);
            return pid;
        }

        public void Kill(int pid)
        {
            computerProcessDictionary[pid].Kill();
        }

    }

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

        public int Start()
        {
            this.cmd = Command.Run(this.computerSoftwareProgram.ProcessPath, this.arguments, options: o => o.DisposeOnExit(false));
            return cmd.ProcessId;
        }
        public void Kill()
        {
            cmd.Process.Kill();
        }
        public bool CloseMainWindow()
        {
            return cmd.Process.CloseMainWindow();
        }
        public void Close()
        {
            cmd.Process.Close();
        }
        public object[] Arguments => arguments;
        public IComputerSoftwareProgram ComputerSoftwareProgram => computerSoftwareProgram;

        public Command Cmd { get => cmd; set => cmd = value; }
    }
}
