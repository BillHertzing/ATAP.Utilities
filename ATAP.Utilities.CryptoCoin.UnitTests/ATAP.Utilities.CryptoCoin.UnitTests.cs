using System;
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
        [Fact]
        public void Test1()
        {

        }
    }
}
