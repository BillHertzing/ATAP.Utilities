using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.CryptoCoin;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Extensions;
using ATAP.Utilities.CryptoCoin.Models;
using ATAP.Utilities.CryptoMiner.Enumerations;
using ATAP.Utilities.CryptoMiner.Models;
using FluentAssertions;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Linq;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.CryptoMiner.UnitTests
{
  public class Fixture
  {
    public ComputerProcesses computerProcesses;
    public int pidUnderTest;

    public Fixture()
    {
      JsonConvert.DefaultSettings = () => new JsonSerializerSettings
      {
        Converters =
                {
            new StringEnumConverter {
            CamelCaseText =
                    true
            }
            }
      };
    }
  }

  public class CryptoMinerUnitTests001 : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture fixture;

    public CryptoMinerUnitTests001(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this.fixture = fixture;
    }

    [Theory]
    [InlineData("{\"HashRatePerCoin\":{\"ETH\":{\"HashRatePerTimeSpan\":20.0,\"HashRateTimeSpan\":{\"IsReadOnly\":false,\"IsAnytime\":false,\"IsMoment\":true,\"HasStart\":true,\"Start\":\"2018-01-18T08:03:44.3486487-05:00\",\"HasEnd\":true,\"End\":\"2018-01-18T08:03:44.3486487-05:00\",\"Duration\":\"00:00:00\",\"DurationDescription\":\"\"}}},\"IsRunning\":false,\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
    internal void MinerGPUDeSerializeFromJSON(string _testdatainput)
    {
      MinerGPU vc = JsonConvert.DeserializeObject<MinerGPU>(_testdatainput);
      vc.Should()
          .NotBeNull();
      vc.DeviceID.Should()
          .Be("10DE 17C8 - 3842");
      vc.BIOSVersion.Should()
          .Be("100.00001.02320.00");
      vc.HashRatePerCoin.Keys.Contains(Coin.ETH)
          .Should()
          .Be(true);
      vc.HashRatePerCoin[Coin.ETH].HashRatePerTimeSpan.Should()
          .Be(20.0);
    }

    [Theory]
    [InlineData("{\"HashRatePerCoin\":{\"ETH\":{\"HashRatePerTimeSpan\":20.0,\"HashRateTimeSpan\":{\"IsReadOnly\":false,\"IsAnytime\":false,\"IsMoment\":true,\"HasStart\":true,\"Start\":\"2018-01-18T08:03:44.3486487-05:00\",\"HasEnd\":true,\"End\":\"2018-01-18T08:03:44.3486487-05:00\",\"Duration\":\"00:00:00\",\"DurationDescription\":\"\"}}},\"IsRunning\":false,\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
    internal void MinerGPUSerializeToJSON(string _testdatainput)
    {
      var hrpc = new ConcurrentObservableDictionary<Coin, HashRate>() {
            { Coin.ETH, new HashRate(20.0,
                                     new TimeSpan(0,
                                                  0,
                                                  1)) }
            };
      VideoCardDiscriminatingCharacteristics vcdc = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
VideoCardMaker.ASUS
&& x.GPUMaker ==
GPUMaker.NVIDEA))
                                                        .Single();
      MinerGPU minerGPU = new MinerGPU(vcdc,
                                       "10DE 17C8 - 3842",
                                       "100.00001.02320.00",
                                       false,
                                       1140,
                                       1753,
                                       11.13,
                                       0.8,
                                       hrpc);
      var str = JsonConvert.SerializeObject(minerGPU);
      str.Should()
          .NotBeNull();
      str.Should()
          .Be(_testdatainput);
    }

    [Theory]
    [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]")]
    public void NetworkInfo1(string _testdatainput)
    {
      _testdatainput.Should()
          .NotBeNull();
    }
    [Theory]
    [InlineData("{\"Period\":\"00:01:00\",\"Watts\":1000.0}")]
    public void RigConfigBuilderFromJSON(string _testdatainput)
    {
      var rigConfig = JsonConvert.DeserializeObject<RigConfig>(_testdatainput);
      rigConfig.Should()
          .NotBeNull();
    }

    [Fact]
    public void RigConfigBuilderToJSON()
    {
      ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW> minerSWs = new ConcurrentObservableDictionary<(MinerSWE minerSWE, string version, Coin[] coins), MinerSW>();
      ConcurrentObservableDictionary<int, MinerGPU> minerGPUs = new ConcurrentObservableDictionary<int, MinerGPU>();
      PowerConsumption pc = new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000.0 };
      TempAndFan tf = new TempAndFan { Temp = 50, FanPct = 95.5 };

      RigConfig rc = RigConfigBuilder.CreateNew()
         .AddMinerSWs(minerSWs)
         .AddMinerGPUs(minerGPUs)
         .AddPowerConsumption(pc)
         .AddTempAndFan(tf)
         .Build();
      var str = JsonConvert.SerializeObject(rc);
      str.Should()
          .NotBeNull();
    }

    [Fact]
    public async void TickerInfo001()
    {
      TickerInfo tickerInfo = new TickerInfo();
      blockChainInfo_ticker r = await tickerInfo.GetAsync();
      r.USD.symbol.Should()
          .Be("$");
    }
  }
}
