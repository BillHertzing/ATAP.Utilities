using System;
using FluentAssertions;
using Newtonsoft.Json;
using Swordfish.NET.Collections;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.CryptoCoin.UnitTests
{
    public class Fixture
    {
        public Fixture()
        {
        }
    }
    public class CryptoCoinUnitTests001 : IClassFixture<Fixture>
    {
        protected Fixture _fixture;
        readonly ITestOutputHelper output;
        public CryptoCoinUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }
        [Theory]
        [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]")]
        public void NetworkInfo1(string _testdatainput)
        {
            _testdatainput.Should().NotBeNull();

        }

        [Fact]
        public async void TickerInfo001()
        {
            TickerInfo tickerInfo = new TickerInfo();
            blockChainInfo_ticker r = await tickerInfo.GetAsync();
            r.USD.symbol.Should().Be("$");
        }

        [Theory]
        [InlineData("[{\"Temp\":20.0,\"FanPct\":0.0},{\"Temp\":50.0,\"FanPct\":50.0},{\"Temp\":85.0,\"FanPct\":100.0}]")]
        public void TempAndFanSetAndGet(string _testdatainput)
        {
            var tempAndFans=    JsonConvert.DeserializeObject<TempAndFan[]>(_testdatainput);
            tempAndFans.Length.Should().Be(3);
            tempAndFans[0].Temp.Should().Be(20);
            tempAndFans[1].Temp.Should().Be(50);
            tempAndFans[2].Temp.Should().Be(85);
            tempAndFans[0].FanPct.Should().Be(0);
            tempAndFans[1].FanPct.Should().Be(50);
            tempAndFans[2].FanPct.Should().Be(100);
        }
        //ToDo add validation tests to ensure illegal values are not allowed
        [Theory]
        [InlineData("{\"Period\":\"00:01:00\",\"Watts\":1000.0}")]
        public void PowerConsumptionSetAndGet(string _testdatainput)
        {
            PowerConsumption pc = new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000.0 };
            var str = JsonConvert.SerializeObject(pc);
            var powerConsumption = JsonConvert.DeserializeObject<PowerConsumption>(_testdatainput);
            powerConsumption.Should().NotBeNull();
            powerConsumption.Watts.Should().Be(1000);
            powerConsumption.Period.TotalSeconds.Should().Be(60);
        }

        [Theory]
        [InlineData("{\"GPUMfgr\":0,\"BIOSVersion\":\"100.00001.02320.00\",\"IsStrapped\":false,\"CoreClock\":1300.0,\"MemClock\":1100.0,\"CoreVoltage\":11.13,\"PowerLimit\":0.8,\"HashRatePerCoin\":{\"ETH\":{\"HashRatePerTimeSpan\":20.0,\"HashRateTimeSpan\":{\"IsReadOnly\":false,\"IsAnytime\":false,\"IsMoment\":true,\"HasStart\":true,\"Start\":\"2018-01-13T07:51:58.0963529-05:00\",\"HasEnd\":true,\"End\":\"2018-01-13T07:51:58.0963529-05:00\",\"Duration\":\"00:00:00\",\"DurationDescription\":\"\"}}},\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"IsRunning\":false}")]
        public void AMDGPUHWSetAndGet(string _testdatainput)
        {
            var hrpc = new ConcurrentObservableDictionary<Coin, HashRate>() { { Coin.ETH, new HashRate(20.0, new Itenso.TimePeriod.TimeBlock(System.DateTime.Now)) } };
            AMDGPUHW g = new AMDGPUHW( "EVGA", "GTX 980 TI", "10DE 17C8 - 3842", "100.00001.02320.00", false, 1140, 1753, 11.13,0.8,hrpc, new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000 }, new TempAndFan() { FanPct = 50.0, Temp = 60 }, false );
            var str = JsonConvert.SerializeObject(g);
            g.Should().NotBeNull();
            /*
            var aMDGPUHW = JsonConvert.DeserializeObject<AMDGPUHW>(_testdatainput);
            aMDGPUHW.Should().NotBeNull();
            aMDGPUHW.SubVendor.Should().Be("EVGA");
            aMDGPUHW.CardName.Should().Be("GTX 980 TI");
            aMDGPUHW.DeviceID.Should().Be("10DE 17C8 - 3842");
            aMDGPUHW.BIOSVersion.Should().Be("100.00001.02320.00");
            aMDGPUHW.IsStrapped.Should().Be(false);
            aMDGPUHW.CoreClock.Should().Be(1100);
            aMDGPUHW.MemClock.Should().Be(1300);
            aMDGPUHW.CoreVoltage.Should().Be(11.13);
            aMDGPUHW.PowerLimit.Should().Be(0.8);
            aMDGPUHW.HashRatePerCoin.Keys.Contains(Coin.ETH).Should().Be(true);
            aMDGPUHW.HashRatePerCoin[Coin.ETH].HashRatePerTimeSpan.Should().Be(20.0);
            aMDGPUHW.HashRatePerCoin[Coin.ETH].HashRateTimeSpan.IsMoment.Should().Be(true);
            aMDGPUHW.PowerConsumption.Watts.Should().Be(1000);
            aMDGPUHW.PowerConsumption.Period.Minutes.Should().Be(60);
            aMDGPUHW.TempAndFan.Temp.Should().Be(60);
            aMDGPUHW.TempAndFan.FanPct.Should().Be(50);
            */
        }

    }
}
