using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.CryptoMiner.Enumerations;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerStatus
  {
    int ID { get; }
    MinerSWE Kind { get; }
    IMinerStatusDetailsAbstract MinerStatusDetails { get; }
    UtcInstant Moment { get; }
    string StatusQueryError { get; }
    string Version { get; }
  }
}
