using System;
using FluentAssertions;
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
    public class CryptoCoinUnitTests001 : IClassFixture<Fixture> {
        protected Fixture _fixture;
        readonly ITestOutputHelper output;
        public CryptoCoinUnitTests001(ITestOutputHelper output, Fixture fixture) {
            this.output = output;
            this._fixture = fixture;
        }
        [Theory]
        [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]")]
        public void NetworkInfo1(string _testdatainput) {
            _testdatainput.Should().NotBeNull();

        }

        [Fact]
        public async void TickerInfo001() {
            TickerInfo tickerInfo = new TickerInfo();
            blockChainInfo_ticker r = await tickerInfo.GetAsync();
            r.USD.symbol.Should().Be("$");
        }
    }
}
