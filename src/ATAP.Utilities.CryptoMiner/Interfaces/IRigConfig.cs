using Itenso.TimePeriod;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IRigConfig
  {
    ITempAndFan CPUTempAndFan { get; }
    ITimeBlock Moment { get; }
    ConcurrentObservableDictionary<int, IMinerGPU> MinerGPUs { get;  }
    ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), IMinerSWAbstract> MinerSWs { get;  }
    IPowerConsumption PowerConsumption { get;  }
  }


}
