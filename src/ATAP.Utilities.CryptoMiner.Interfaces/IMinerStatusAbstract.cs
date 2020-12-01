using ATAP.Utilities.CryptoMiner.Enumerations;
using Itenso.TimePeriod;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerStatusAbstract
  {
    int ID { get; }
    IMinerStatusDetailsAbstract MinerStatusDetails { get; }
    ITimeBlock Moment { get; }
    string StatusQueryError { get; }
    string Version { get; }
  }
}
