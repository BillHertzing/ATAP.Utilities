using ATAP.Utilities.CryptoCoin.Enumerations;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerSWAbstract
  {
    Coin[] CoinsMined { get; }
    string[][] Pools { get; set; }
  }
}
