using System;
using System.Collections.Generic;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Interfaces;
using Itenso.TimePeriod;

namespace ATAP.Utilities.CryptoCoin.Models
{

  public class CryptoCoinNetworkInfo : ICryptoCoinNetworkInfo
  {
    public CryptoCoinNetworkInfo()
    {
    }

    public CryptoCoinNetworkInfo(TimeBlock avgBlockTime, double blockRewardPerBlock, Coin coin, IHashRate hashRate)
    {
      AvgBlockTime = avgBlockTime ?? throw new ArgumentNullException(nameof(avgBlockTime));
      BlockRewardPerBlock = blockRewardPerBlock;
      Coin = coin;
      HashRate = hashRate ?? throw new ArgumentNullException(nameof(hashRate));
    }

    public TimeBlock AvgBlockTime { get; set; }
    public double BlockRewardPerBlock { get; set; }
    public Coin Coin { get; set; }
    public IHashRate HashRate { get; set; }

    public static double AverageShareOfBlockRewardPerSpanFast(AverageShareOfBlockRewardDT data, TimeBlock timeBlock)
    {
      // normalize into minerHashRateAsAPercentOfTotal the MinerHashRate / NetworkHashRate using the TimeBlock of the Miner
      HashRate minerHashRateAsAPercentOfTotal = default;// ToDo: Fix this calculation data.MinerHashRate / data.NetworkHashRate;
      // normalize the BlockRewardPerSpan to the same span the Miner HashRate span
      //ToDo Fix this calculation
      // normalize the BlockRewardPerSpan to the same span the network HashRate span
      double normalizedBlockCreationSpan = data.AverageBlockCreationSpan.Duration.Ticks /
          data.NetworkHashRate.HashRateTimeSpan.Duration().Ticks;
      double normalizedBlockRewardPerSpan = data.BlockRewardPerBlock /
          (data.AverageBlockCreationSpan.Duration.Ticks *
              normalizedBlockCreationSpan);
      // The number of block rewards found, on average, within a given TimeBlock, is number of blocks in the span, times the fraction of the NetworkHashRate contributed by the miner
      return normalizedBlockRewardPerSpan *
          (minerHashRateAsAPercentOfTotal.HashRatePerTimeSpan /
              data.NetworkHashRate.HashRatePerTimeSpan);
    }
    public static double AverageShareOfBlockRewardPerSpanSafe(AverageShareOfBlockRewardDT data, TimeBlock timeSpan)
    {
      // ToDo: Add parameter checking
      return AverageShareOfBlockRewardPerSpanFast(data, timeSpan);
    }

  }

}
