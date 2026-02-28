using ATAP.Utilities.CryptoCoin.Interfaces;
using Itenso.TimePeriod;
using System;

namespace ATAP.Utilities.CryptoCoin.Models
{
  public class AverageShareOfBlockRewardDT : IAverageShareOfBlockRewardDT
  {
    public AverageShareOfBlockRewardDT()
    {
    }

    public AverageShareOfBlockRewardDT(TimeBlock averageBlockCreationSpan, double blockRewardPerBlock, TimeBlock duration, IHashRate minerHashRate, IHashRate networkHashRate)
    {
      AverageBlockCreationSpan = averageBlockCreationSpan ?? throw new ArgumentNullException(nameof(averageBlockCreationSpan));
      BlockRewardPerBlock = blockRewardPerBlock;
      Duration = duration ?? throw new ArgumentNullException(nameof(duration));
      MinerHashRate = minerHashRate ?? throw new ArgumentNullException(nameof(minerHashRate));
      NetworkHashRate = networkHashRate ?? throw new ArgumentNullException(nameof(networkHashRate));
    }

    public TimeBlock AverageBlockCreationSpan { get; }
    public double BlockRewardPerBlock { get; set; }
    public TimeBlock Duration { get; set; }
    public IHashRate MinerHashRate { get; set; }
    public IHashRate NetworkHashRate { get; set; }
  }
}
