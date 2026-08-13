using ATAP.Utilities.CryptoCoin.Interfaces;
using ATAP.Utilities.DateTime.Interfaces;
using System;

namespace ATAP.Utilities.CryptoCoin.Models
{
  public class AverageShareOfBlockRewardDT : IAverageShareOfBlockRewardDT
  {
    public AverageShareOfBlockRewardDT()
    {
    }

    public AverageShareOfBlockRewardDT(TemporalDuration averageBlockCreationSpan, double blockRewardPerBlock, TemporalDuration duration, IHashRate minerHashRate, IHashRate networkHashRate)
    {
      AverageBlockCreationSpan = averageBlockCreationSpan;
      BlockRewardPerBlock = blockRewardPerBlock;
      Duration = duration;
      MinerHashRate = minerHashRate ?? throw new ArgumentNullException(nameof(minerHashRate));
      NetworkHashRate = networkHashRate ?? throw new ArgumentNullException(nameof(networkHashRate));
    }

    public TemporalDuration AverageBlockCreationSpan { get; }
    public double BlockRewardPerBlock { get; set; }
    public TemporalDuration Duration { get; set; }
    public IHashRate MinerHashRate { get; set; }
    public IHashRate NetworkHashRate { get; set; }
  }
}
