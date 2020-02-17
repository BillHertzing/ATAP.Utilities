using System.Collections.Generic;
using System.Threading.Tasks;
using ATAP.Utilities.ComputerInventory.Models;

namespace ATAP.Utilities.CryptoMiner.Models
{
  public interface IMinerProcess
  {
    Task<IMinerStatus> StatusFetchAsync();
    Task<List<TuneMinerGPUsResult>> TuneMiners();
  }

  public abstract class MinerProcess : ComputerProcess, IMinerProcess
  {
        public MinerProcess(MinerSW computerSoftwareProgram, params object[] arguments) : base(computerSoftwareProgram, arguments)
        {
        }

        //ToDo: Add a cancellation token
        public abstract Task<IMinerStatus> StatusFetchAsync();

    //ToDo: Add a cancellation token
    public abstract  Task<List<TuneMinerGPUsResult>> TuneMiners();

  }

}
