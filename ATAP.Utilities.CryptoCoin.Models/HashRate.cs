using System;
using ATAP.Utilities.CryptoCoin.Interfaces;

namespace ATAP.Utilities.CryptoCoin.Models
{
  public class HashRate : IHashRate
  {
    public HashRate()
    {
    }

    public HashRate(double hashRatePerTimeSpan, TimeSpan hashRateTimeSpan)
    {
      HashRatePerTimeSpan = hashRatePerTimeSpan;
      HashRateTimeSpan = hashRateTimeSpan;
    }


    // overload operator -
    public static IHashRate operator -(HashRate a, IHashRate b)
    {
      if (a.HashRateTimeSpan == b.HashRateTimeSpan)
      {
        return new HashRate(a.HashRatePerTimeSpan - b.HashRatePerTimeSpan, a.HashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.HashRatePerTimeSpan -
            (b.HashRatePerTimeSpan *
                (a.HashRateTimeSpan.Duration().Ticks /
                    b.HashRateTimeSpan.Duration().Ticks)),
                            a.HashRateTimeSpan);
      }
    }

    // overload operator *
    public static IHashRate operator *(HashRate a, IHashRate b)
    {
      if (a.HashRateTimeSpan == b.HashRateTimeSpan)
      {
        return new HashRate(a.HashRatePerTimeSpan * b.HashRatePerTimeSpan, a.HashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.HashRatePerTimeSpan *
            (b.HashRatePerTimeSpan *
                (a.HashRateTimeSpan.Duration().Ticks /
                    b.HashRateTimeSpan.Duration().Ticks)),
                            a.HashRateTimeSpan);
      }
    }
    // overload operator *
    public static IHashRate operator /(HashRate a, IHashRate b)
    {
      if (a.HashRateTimeSpan == b.HashRateTimeSpan)
      {
        return new HashRate(a.HashRatePerTimeSpan / b.HashRatePerTimeSpan, a.HashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.HashRatePerTimeSpan /
            (b.HashRatePerTimeSpan *
                (a.HashRateTimeSpan.Duration().Ticks /
                    b.HashRateTimeSpan.Duration().Ticks)),
                            a.HashRateTimeSpan);
      }
    }

    // overload operator +
    public static IHashRate operator +(HashRate a, IHashRate b)
    {
      if (a.HashRateTimeSpan == b.HashRateTimeSpan)
      {
        return new HashRate(a.HashRatePerTimeSpan + b.HashRatePerTimeSpan, a.HashRateTimeSpan);
      }
      else
      {
        return new HashRate(a.HashRatePerTimeSpan +
            (b.HashRatePerTimeSpan *
                (a.HashRateTimeSpan.Duration().Ticks /
                    b.HashRateTimeSpan.Duration().Ticks)),
                            a.HashRateTimeSpan);
      }
    }

    public static IHashRate ChangeTimeSpan(IHashRate a, IHashRate b)
    {
      // no parameter checking
      double normalizedTimeSpan = a.HashRateTimeSpan.Duration().Ticks / b.HashRateTimeSpan.Duration().Ticks;
      return new HashRate(a.HashRatePerTimeSpan *
          (a.HashRateTimeSpan.Duration().Ticks /
              b.HashRateTimeSpan.Duration().Ticks),
                          a.HashRateTimeSpan);
    }

    public double HashRatePerTimeSpan { get; set; }
    public TimeSpan HashRateTimeSpan { get; set; }
  }

}
