using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface ICryptoCoinNetworkInfo
  {
    TemporalDuration AvgBlockTime { get; set; }
    double BlockRewardPerBlock { get; set; }
    Coin Coin { get; set; }
    IHashRate HashRate { get; set; }
  }

}
