using System.Collections.Generic;
using System.Threading.Tasks;
using ATAP.Utilities.ComputerInventory.Configuration;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using Medallion.Shell;
using ATAP.Utilities.CryptoMiner.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models
{


  public abstract class MinerProcessAbstract : ComputerProcess, IMinerProcess
  {
    public MinerProcessAbstract(MinerSWAbstract computerSoftwareProgram, Command command, params object[] arguments) : base(computerSoftwareProgram, command, arguments)
    {
    }

    //ToDo: Add a cancellation token
    public abstract Task<IMinerStatusAbstract> StatusFetchAsync();

    //ToDo: Add a cancellation token
    public abstract Task<List<ITuneMinerGPUsResult>> TuneMinersAsync();

  }

}
