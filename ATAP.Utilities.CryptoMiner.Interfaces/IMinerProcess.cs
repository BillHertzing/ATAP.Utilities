using System.Collections.Generic;
using System.Threading.Tasks;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerProcess
  {
    Task<IMinerStatusAbstract> StatusFetchAsync();
    Task<List<ITuneMinerGPUsResult>> TuneMinersAsync();
  }
}
