using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.DateTime.Interfaces;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerStatusAbstract
  {
    int ID { get; }
    IMinerStatusDetailsAbstract MinerStatusDetails { get; }
    UtcInstant Moment { get; }
    string StatusQueryError { get; }
    string Version { get; }
  }
}
