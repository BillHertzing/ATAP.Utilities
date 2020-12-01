using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoMiner.Enumerations;
using UnitsNet.Units;

namespace ATAP.Utilities.CryptoMiner.Interfaces
{
  public interface IMinerConfigSettings
  {
    int ApiPort { get; set; }
    Coin[] CoinsMined { get; set; }
    int[][] CoinVideoCardIntensity { get; set; }
    MinerSWE Kind { get; }
    FrequencyUnit MemoryClock { get; set; }
    ElectricPotentialDcUnit MemoryVoltage { get; set; }
    int NumVideoCardsToPowerUpInParallel { get; set; }
    string[] PoolPasswords { get; set; }
    string[][] Pools { get; set; }
    string[] PoolWallets { get; set; }
  }
}
