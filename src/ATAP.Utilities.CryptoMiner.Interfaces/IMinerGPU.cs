using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Interfaces;
using ATAP.Utilities.CryptoCoin.Models;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerGPU
  {
    ConcurrentObservableDictionary<Coin, IHashRate> HashRatePerCoin { get; }
  }
}
