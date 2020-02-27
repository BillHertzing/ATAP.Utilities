using ATAP.Utilities.CryptoCoin.Enumerations;
using Itenso.TimePeriod;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface ICryptoCoinNetworkInfo
  {
    TimeBlock AvgBlockTime { get; set; }
    double BlockRewardPerBlock { get; set; }
    Coin Coin { get; set; }
    IHashRate HashRate { get; set; }
  }

}
