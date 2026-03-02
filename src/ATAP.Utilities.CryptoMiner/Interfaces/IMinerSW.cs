using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerSW
  {
    Coin[] CoinsMined { get; }
    MinerSWE Kind { get; }
    string[][] Pools { get; set; }
  }
}
