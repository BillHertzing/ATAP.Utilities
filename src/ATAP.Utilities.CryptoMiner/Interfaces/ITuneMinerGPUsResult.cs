using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;
using UnitsNet;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface ITuneMinerGPUsResult
  {
    Frequency CoreClock { get; }
    ElectricPotentialDc CoreVoltage { get; }
    ConcurrentObservableDictionary<Coin, HashRate> HashRates { get; }
    Frequency MemClock { get; }
    Power PowerConsumption { get; }
  }
}
