using FluentAssertions;
using System.Text;
using Xunit;
using ATAP.Services.TcpWithResilience.Interfaces;

namespace ATAP.Services.TcpWithResilience.UnitTests
{
  public class Fixture
    {
        #region MOQs
        // a MOQ for the async web calls used for Term1
        //public Mock<IWebGet> mockTerm1;
        #endregion

        //public ISSDataConcrete iSSData;

        public Fixture()
        {
            /* create a policy registry, to be injected into the SUT */
            /* create a Tcp service with associated policies */
ITcpWithResilience TcpWithResilience;
            /*
            mockTerm1 = new Mock<ITcpWithResilience>();
            mockTerm1.Setup(webGet => webGet.AsyncWebGet<byte[]>("A"))
                .Callback(() => Task.Delay(new TimeSpan(0, 0, 1)))
                .ReturnsAsync("[{\"Temp\":20.0,\"FanPct\":0.0},{\"Temp\":50.0,\"FanPct\":50.0},{\"Temp\":85.0,\"FanPct\":100.0}]");
            mockTerm1.Setup(webGet => webGet.AsyncWebGet<byte[]>("B"))
                .Callback(() => Task.Delay(new TimeSpan(0, 0, 1)))
                .ReturnsAsync("[{\"Temp\":60.0,\"FanPct\":50.0},{\"Temp\":45.0,\"FanPct\":65.0},{\"Temp\":15.0,\"FanPct\":99.9}]");
                */
        }
    }
    public class TCPUnitTests001 : IClassFixture<Fixture>
    {

        [Theory]
        [InlineData("[{\"Temp\":20.0,\"FanPct\":0.0},{\"Temp\":50.0,\"FanPct\":50.0},{\"Temp\":85.0,\"FanPct\":100.0}]")]
        public async void claymorestatus(string _testdatainput)
        {
            //arrange 
            var host = "ncat-m01";
            var port = 21200;
            var message = "{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"miner_getstat1\"}";
            byte[] responsebuffer = new byte[Tcp.defaultMaxResponseBufferSize];

            //act
            responsebuffer = await Tcp.FetchAsync(host, port, message);
            string str = Encoding.ASCII.GetString(responsebuffer);
            //assert
            // first, assert the response buffer is correct
            responsebuffer[0].Should().BeGreaterThan(0);
            // Then assert on the str
            str.Should()
                .Be(_testdatainput);
        }
    }
}

