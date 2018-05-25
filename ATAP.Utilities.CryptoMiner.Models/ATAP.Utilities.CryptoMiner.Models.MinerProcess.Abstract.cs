using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ComputerInventory.Extensions;

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
