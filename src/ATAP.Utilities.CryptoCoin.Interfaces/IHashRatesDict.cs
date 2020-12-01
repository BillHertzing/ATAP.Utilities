using System.Collections.Generic;
using ATAP.Utilities.CryptoCoin.Enumerations;

namespace ATAP.Utilities.CryptoCoin.Interfaces
{
  public interface IHashRatesDict
  {
    Dictionary<Coin, IHashRate> HashRates { get; set; }
  }

}
