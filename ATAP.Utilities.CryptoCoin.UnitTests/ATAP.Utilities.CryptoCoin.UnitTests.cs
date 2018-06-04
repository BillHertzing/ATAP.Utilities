using System;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using ATAP.Utilities.ComputerInventory;
using FluentAssertions;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;
using Xunit;
using Xunit.Abstractions;
<<<<<<< HEAD
=======
using ATAP.Utilities.CryptoCoin.Extensions;
using ATAP.Utilities.CryptoCoin.Enumerations;
using ATAP.Utilities.CryptoCoin.Models;
>>>>>>> RefactorCryptoCurrencyToExtractDTOs

namespace ATAP.Utilities.CryptoCoin.UnitTests
{
    public class Fixture
    {
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

    public class CryptoCoinUnitTests001 : IClassFixture<Fixture>
    {
        readonly ITestOutputHelper output;
        protected Fixture _fixture;

        public CryptoCoinUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }

        [Theory]
        [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]")]
        public void NetworkInfo1(string _testdatainput)
        {
            _testdatainput.Should()
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
