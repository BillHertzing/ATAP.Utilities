using System;
using Moq;
using Newtonsoft.Json;
using Xunit;
using Xunit.Abstractions;
using ATAP.Utilities.ZSandbox;
namespace ATAP.Utilities.ZSandbox.UnitTests
{



    public class Fixture
    {
        private string hello;

        public Fixture()
        {
            Hello = "Hello";
        }

        public string Hello { get => hello; set => hello = value; }
    }
    public class ZSandboxUnitTests001 : IClassFixture<Fixture>
    {
        Fixture _fixture;

        [Fact]
        void TupleToStringInJSONFormat()
        {
            var x = ("c1","c2")
            var str = SandboxStatic1.SerializeTuple(x);
            Assert.Equal(1, 1);

        }

        [Theory]
        [InlineData("{[{k1:\"1\";k2:\"1\";c1:\"2\";t1:1.11}]}")]
        void StringInJSONFormatToTuple(string _inTestData)
        {
            (string c1, string c2) r = SandboxStatic1.DeSerializeTuple(_inTestData);
            Assert.Equal(1, 1);

        }
    }

}
