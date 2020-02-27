using System;
using System.Collections.Generic;

namespace ATAP.Utilities.CryptoCoin.Models
{
  public class BlockReward : IBlockReward, IEquatable<BlockReward>
  {
    public BlockReward()
    {
    }

    public BlockReward(double blockRewardPerBlock)
    {
      BlockRewardPerBlock = blockRewardPerBlock;
    }

    public double BlockRewardPerBlock { get; set; }

    public override bool Equals(object obj)
    {
      return Equals(obj as BlockReward);
    }

    public bool Equals(BlockReward other)
    {
      return other != null &&
             BlockRewardPerBlock == other.BlockRewardPerBlock;
    }

    public override int GetHashCode()
    {
      return -1035858563 + BlockRewardPerBlock.GetHashCode();
    }

    public static bool operator ==(BlockReward left, BlockReward right)
    {
      return EqualityComparer<BlockReward>.Default.Equals(left, right);
    }

    public static bool operator !=(BlockReward left, BlockReward right)
    {
      return !(left == right);
    }
  }

}
