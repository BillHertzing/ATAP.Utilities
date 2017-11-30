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
            var x = (k1:"k1", k2:"k2");
            var str = SandboxStatic1.SerializeTuple(x);
            Assert.Equal("{\"Item1\":\"k1\",\"Item2\":\"k2\"}", str);

        }

        [Theory]
        [InlineData("{\"Item1\":\"k1\",\"Item2\":\"k2\"}")]
        void StringInJSONFormatToTuple(string _inTestData)
        {
            (string k1, string k2) r = SandboxStatic1.DeSerializeTuple(_inTestData);
            Assert.Equal((k1: "k1", k2: "k2"), r);

        }
    }

}
