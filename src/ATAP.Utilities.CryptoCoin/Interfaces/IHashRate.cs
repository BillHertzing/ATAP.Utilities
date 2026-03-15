using System;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface IHashRate
  {
    double HashRatePerTimeSpan { get; set; }
    TimeSpan HashRateTimeSpan { get; set; }
  }
}
