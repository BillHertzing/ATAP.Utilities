using System.Collections.Generic;
using System.Threading.Tasks;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.CryptoMiner.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Models
{


  public abstract class MinerProcessAbstract : ComputerProcess, IMinerProcess
  {
    public MinerProcessAbstract(MinerSWAbstract computerSoftwareProgram,  params object[] arguments) : base(computerSoftwareProgram,  arguments)
    {
    }

    //ToDo: Add a cancellation token
    public abstract Task<IMinerStatusAbstract> StatusFetchAsync();

    //ToDo: Add a cancellation token
    public abstract Task<List<ITuneMinerGPUsResult>> TuneMinersAsync();

  }

}
