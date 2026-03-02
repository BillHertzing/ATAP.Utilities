using Itenso.TimePeriod;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface IAverageShareOfBlockRewardDT
  {
    TimeBlock AverageBlockCreationSpan { get; }
    double BlockRewardPerBlock { get; set; }
    TimeBlock Duration { get; set; }
    IHashRate MinerHashRate { get; set; }
    IHashRate NetworkHashRate { get; set; }
  }


}
