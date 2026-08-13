using System;
using System.Collections.Generic;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Interfaces;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.CryptoCoin.Models
{

  public class CryptoCoinNetworkInfo : ICryptoCoinNetworkInfo
  {
    public CryptoCoinNetworkInfo()
    {
    }

    public CryptoCoinNetworkInfo(TemporalDuration avgBlockTime, double blockRewardPerBlock, Coin coin, IHashRate hashRate)
    {
      AvgBlockTime = avgBlockTime;
      BlockRewardPerBlock = blockRewardPerBlock;
      Coin = coin;
      HashRate = hashRate ?? throw new ArgumentNullException(nameof(hashRate));
    }

    public TemporalDuration AvgBlockTime { get; set; }
    public double BlockRewardPerBlock { get; set; }
    public Coin Coin { get; set; }
    public IHashRate HashRate { get; set; }

    public static double AverageShareOfBlockRewardPerSpanFast(AverageShareOfBlockRewardDT data, TemporalDuration duration)
    {
      double minerRatePerTick = data.MinerHashRate.HashRatePerTimeSpan /
          data.MinerHashRate.HashRateTimeSpan.Duration().Ticks;
      double networkRatePerTick = data.NetworkHashRate.HashRatePerTimeSpan /
          data.NetworkHashRate.HashRateTimeSpan.Duration().Ticks;
      double expectedBlocks = (double)duration.Ticks / data.AverageBlockCreationSpan.Ticks;

      return expectedBlocks * data.BlockRewardPerBlock * (minerRatePerTick / networkRatePerTick);
    }

    public static double AverageShareOfBlockRewardPerSpanSafe(AverageShareOfBlockRewardDT data, TemporalDuration duration)
    {
      ArgumentNullException.ThrowIfNull(data);

      if (data.AverageBlockCreationSpan.Ticks == 0)
      {
        throw new DivideByZeroException("The average block creation duration must be greater than zero.");
      }

      if (data.MinerHashRate.HashRateTimeSpan.Duration().Ticks == 0 ||
          data.NetworkHashRate.HashRateTimeSpan.Duration().Ticks == 0 ||
          data.NetworkHashRate.HashRatePerTimeSpan == 0)
      {
        throw new DivideByZeroException("Hash-rate spans and the network hash rate must be greater than zero.");
      }

      double result = AverageShareOfBlockRewardPerSpanFast(data, duration);
      if (!double.IsFinite(result))
      {
        throw new OverflowException("The expected block-reward share is outside the finite Double range.");
      }

      return result;
    }

  }

}
