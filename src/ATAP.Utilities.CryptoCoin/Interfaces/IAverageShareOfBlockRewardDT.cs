using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface IAverageShareOfBlockRewardDT
  {
    TemporalDuration AverageBlockCreationSpan { get; }
    double BlockRewardPerBlock { get; set; }
    TemporalDuration Duration { get; set; }
    IHashRate MinerHashRate { get; set; }
    IHashRate NetworkHashRate { get; set; }
  }


}
