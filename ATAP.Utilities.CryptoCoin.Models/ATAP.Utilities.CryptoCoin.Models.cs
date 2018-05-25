using System;
using System.Collections.Generic;
using ATAP.Utilities.CryptoCoin.Enumerations;
using Itenso.TimePeriod;

namespace ATAP.Utilities.CryptoCoin.Models
{

  public class HashRate
  {
    double hashRatePerTimeSpan;
    TimeSpan hashRateTimeSpan;

    public HashRate(double hashRatePerTimeSpan, TimeSpan hashRateSpan)
    {
      this.hashRatePerTimeSpan = hashRatePerTimeSpan;
      this.hashRateTimeSpan = hashRateSpan;
    }

    // overload operator -
    public static HashRate operator -(HashRate a, HashRate b)
    {
      if (a.hashRateTimeSpan == b.hashRateTimeSpan)
      {
        return new HashRate(a.hashRatePerTimeSpan - b.hashRatePerTimeSpan, a.hashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.hashRatePerTimeSpan -
            (b.hashRatePerTimeSpan *
                (a.hashRateTimeSpan.Duration().Ticks /
                    b.hashRateTimeSpan.Duration().Ticks)),
                            a.hashRateTimeSpan);
      }
    }

    // overload operator *
    public static HashRate operator *(HashRate a, HashRate b)
    {
      if (a.hashRateTimeSpan == b.hashRateTimeSpan)
      {
        return new HashRate(a.hashRatePerTimeSpan * b.hashRatePerTimeSpan, a.hashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.hashRatePerTimeSpan *
            (b.hashRatePerTimeSpan *
                (a.hashRateTimeSpan.Duration().Ticks /
                    b.hashRateTimeSpan.Duration().Ticks)),
                            a.hashRateTimeSpan);
      }
    }
    // overload operator *
    public static HashRate operator /(HashRate a, HashRate b)
    {
      if (a.hashRateTimeSpan == b.hashRateTimeSpan)
      {
        return new HashRate(a.hashRatePerTimeSpan / b.hashRatePerTimeSpan, a.hashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.hashRatePerTimeSpan /
            (b.hashRatePerTimeSpan *
                (a.hashRateTimeSpan.Duration().Ticks /
                    b.hashRateTimeSpan.Duration().Ticks)),
                            a.hashRateTimeSpan);
      }
    }

    // overload operator +
    public static HashRate operator +(HashRate a, HashRate b)
    {
      if (a.hashRateTimeSpan == b.hashRateTimeSpan)
      {
        return new HashRate(a.hashRatePerTimeSpan + b.hashRatePerTimeSpan, a.hashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.hashRatePerTimeSpan +
            (b.hashRatePerTimeSpan *
                (a.hashRateTimeSpan.Duration().Ticks /
                    b.hashRateTimeSpan.Duration().Ticks)),
                            a.hashRateTimeSpan);
      }
    }

    public static HashRate ChangeTimeSpan(HashRate a, HashRate b)
    {
      // no parameter checking
      double normalizedTimeSpan = a.HashRateTimeSpan.Duration().Ticks / b.HashRateTimeSpan.Duration().Ticks;
      return new HashRate(a.hashRatePerTimeSpan *
          (a.hashRateTimeSpan.Duration().Ticks /
              b.hashRateTimeSpan.Duration().Ticks),
                          a.hashRateTimeSpan);
    }

    public double HashRatePerTimeSpan { get { return hashRatePerTimeSpan; } set { hashRatePerTimeSpan = value; } }
    public TimeSpan HashRateTimeSpan { get { return hashRateTimeSpan; } set { hashRateTimeSpan = value; } }
  }

  public class BlockReward
  {
    double blockRewardPerBlock;

    public BlockReward(double blockRewardPerBlock)
    {
      this.blockRewardPerBlock = blockRewardPerBlock;
    }

    public double BlockRewardPerBlock { get { return blockRewardPerBlock; } set { blockRewardPerBlock = value; } }
  }

  public interface ICryptoCoinNetworkInfo
  {
    TimeBlock AvgBlockTime { get; set; }
    Coin Coin { get; set; }
    HashRate HashRate { get; set; }
  }

  public partial class CryptoCoinNetworkInfo : ICryptoCoinNetworkInfo
  {
    TimeBlock avgBlockTime;
    double blockRewardPerBlock;
    Coin coin;
    HashRate hashRate;

    public CryptoCoinNetworkInfo(Coin coin)
    {
      this.coin = coin;
    }
    public CryptoCoinNetworkInfo(Coin coin, HashRate hashRate, TimeBlock avgBlockTime, double blockRewardPerBlock)
    {
      this.coin = coin;
      this.hashRate = hashRate;
      this.avgBlockTime = avgBlockTime;
      this.blockRewardPerBlock = blockRewardPerBlock;
    }
    public Coin Coin { get => coin; set => coin = value; }
    public HashRate HashRate { get => hashRate; set => hashRate = value; }
    public TimeBlock AvgBlockTime { get => avgBlockTime; set => avgBlockTime = value; }
  }

  public partial class CryptoCoinNetworkInfo : ICryptoCoinNetworkInfo
  {
    
    public static double AverageShareOfBlockRewardPerSpanFast(AverageShareOfBlockRewardDT data, TimeBlock timeBlock)
    {
      // normalize into minerHashRateAsAPercentOfTotal the MinerHashRate / NetworkHashRate using the TimeBlock of the Miner
      HashRate minerHashRateAsAPercentOfTotal = data.MinerHashRate / data.NetworkHashRate;
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
  public interface IAverageShareOfBlockRewardDT
  {
    TimeBlock AverageBlockCreationSpan { get; set; }
    double BlockRewardPerBlock { get; set; }
    TimeBlock Duration { get; set; }
    HashRate MinerHashRate { get; set; }
    HashRate NetworkHashRate { get; set; }
  }

  public interface IROAverageShareOfBlockRewardDT
  {
    TimeBlock AverageBlockCreationSpan { get; }
    double BlockRewardPerBlock { get; }
    TimeBlock Duration { get; }
    HashRate MinerHashRate { get; }
    HashRate NetworkHashRate { get; }
  }
  public interface IHashRatesDict
  {
    Dictionary<Coin, HashRate> HashRates { get; set; }
  }
  /* the minimum data fields needed to calculate one miners average share of total coins mined in a time period */
  public class AverageShareOfBlockRewardDT : IAverageShareOfBlockRewardDT, IROAverageShareOfBlockRewardDT
  {
    TimeBlock averageBlockCreationSpan;

    double blockRewardPerBlock;
    TimeBlock duration;
    HashRate minerHashRate;
    HashRate networkHashRate;

    public AverageShareOfBlockRewardDT(TimeBlock averageBlockCreationSpan, TimeBlock duration, HashRate minerHashRate, HashRate networkHashRate, double blockRewardPerBlock)
    {
      this.averageBlockCreationSpan = averageBlockCreationSpan;
      this.duration = duration;
      this.minerHashRate = minerHashRate;
      this.networkHashRate = networkHashRate;

      this.blockRewardPerBlock = blockRewardPerBlock;
    }

    public TimeBlock AverageBlockCreationSpan {
      get { return averageBlockCreationSpan; }
      set { averageBlockCreationSpan = value; }
    }
    public double BlockRewardPerBlock {
      get { return blockRewardPerBlock; }
      set { blockRewardPerBlock = value; }
    }
    public TimeBlock Duration {
      get { return duration; }
      set { duration = value; }
    }
    public HashRate MinerHashRate {
      get { return minerHashRate; }
      set { minerHashRate = value; }
    }
    public HashRate NetworkHashRate {
      get { return networkHashRate; }
      set { networkHashRate = value; }
    }
  }
  public interface IFees
  {
    Fees Fees { get; set; }
  }

  public class Fees
  {
    double feeAsAPercent;

    public Fees()
    {
      feeAsAPercent = default(double);
    }
    public Fees(double feeAsAPercent)
    {
      this.feeAsAPercent = feeAsAPercent;
    }

    public override string ToString()
    {
      return $"{FeeAsAPercent}";
    }

    public double FeeAsAPercent { get => feeAsAPercent; set => feeAsAPercent = value; }
  }

}
