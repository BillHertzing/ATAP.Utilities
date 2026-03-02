
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IRigConfigBuilder
  {
    IRigConfigBuilder AddMinerGPUs(ConcurrentObservableDictionary<int, IMinerGPU> minerGPUs);
    IRigConfigBuilder AddMinerSWs(ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), IMinerSWAbstract> minerSWs);
    IRigConfigBuilder AddPowerConsumption(PowerConsumption powerConsumption);
    IRigConfigBuilder AddTempAndFan(TempAndFan cPUTempAndFan);
  }


}
