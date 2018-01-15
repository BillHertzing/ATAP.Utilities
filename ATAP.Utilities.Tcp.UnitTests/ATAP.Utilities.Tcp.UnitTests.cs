using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ATAP.Utilities.Tcp;
using FluentAssertions;
using Moq;
using Newtonsoft.Json;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.Tcp.UnitTests
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
            /*
            mockTerm1 = new Mock<ITcp>();
            mockTerm1.Setup(webGet => webGet.AsyncWebGet<double>("A"))
                .Callback(() => Task.Delay(new TimeSpan(0, 0, 1)))
                .ReturnsAsync(100.0);
            mockTerm1.Setup(webGet => webGet.AsyncWebGet<double>("B"))
                .Callback(() => Task.Delay(new TimeSpan(0, 0, 1)))
                .ReturnsAsync(200.0);
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
            str.Length.Should().BeGreaterThan(0);
        }
    }
}

