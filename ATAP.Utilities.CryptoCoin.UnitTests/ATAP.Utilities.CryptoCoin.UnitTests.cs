using System;
using FluentAssertions;
using Newtonsoft.Json;
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
        [InlineData("[{20,0},{50,50},{85,100}]")]
        public void TempAndFanOSetAndGet(string _testdatainput)
        {
            TempAndFan[] tempAndFanOs = JsonConvert.DeserializeObject<TempAndFan[]>(_testdatainput);
            tempAndFanOs.Length.Should().Be(3);
            tempAndFanOs[0].Temp.Should().Be(20);
            tempAndFanOs[1].Temp.Should().Be(50);
            tempAndFanOs[2].Temp.Should().Be(85);
            tempAndFanOs[0].FanPct.Should().Be(0);
            tempAndFanOs[1].FanPct.Should().Be(50);
            tempAndFanOs[2].FanPct.Should().Be(100);
        }
        //ToDo add validation tests to ensure illegal values are not allowed

    }
}
