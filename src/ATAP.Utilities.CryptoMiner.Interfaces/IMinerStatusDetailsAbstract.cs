using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin.Enumerations;
using UnitsNet;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerStatusDetailsAbstract
  {
    ConcurrentObservableDictionary<int, Ratio> PerGPUFanPct { get; }
    ConcurrentObservableDictionary<int, ConcurrentObservableDictionary<Coin, double>> PerGPUPerCoinHashRate { get; }
    ConcurrentObservableDictionary<int, Power> PerGPUPowerConsumption { get; }
    ConcurrentObservableDictionary<int, Temperature> PerGPUTemperature { get; }
    string RunningTime { get; }
    ConcurrentObservableDictionary<Coin, double> TotalPerCoinHashRate { get; }
    ConcurrentObservableDictionary<Coin, int> TotalPerCoinInvalidShares { get; }
    ConcurrentObservableDictionary<Coin, int> TotalPerCoinPoolSwitches { get; }
    ConcurrentObservableDictionary<Coin, int> TotalPerCoinRejectedShares { get; }
    ConcurrentObservableDictionary<Coin, int> TotalPerCoinShares { get; }
    string Version { get; }
  }
}
