using ATAP.Utilities.CryptoCoin;
using FluentAssertions;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;
using System;
using System.Linq;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{
    public class Fixture
    {
        public Fixture()
        {
            JsonConvert.DefaultSettings = () => new JsonSerializerSettings { Converters = { new StringEnumConverter()} };
        }
    }
    public class ComputerInventoryUnitTests001 : IClassFixture<Fixture>
    {
        protected Fixture _fixture;
        readonly ITestOutputHelper output;
        public ComputerInventoryUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }

        [Theory]
        [InlineData("{\"Temp\":50.0,\"FanPct\":95.5}")]
        public void TempAndFanSerializeToJSON(string _testdatainput)
        {
            TempAndFan tempAndFan = new TempAndFan { Temp = 50, FanPct = 95.5 };
            string str = JsonConvert.SerializeObject(tempAndFan);
            str.Should().NotBeNull();
            str.Should().Be(_testdatainput);
        }
        [Theory]
        [InlineData("{\"Temp\":20.0,\"FanPct\":0.0}")]
        public void TempAndFanDeSerializeFromJSON(string _testdatainput)
        {
            var tempAndFan = JsonConvert.DeserializeObject<TempAndFan>(_testdatainput);
            tempAndFan.Should().NotBeNull();
            tempAndFan.Temp.Should().Be(20);
            tempAndFan.FanPct.Should().Be(0);
        }
        [Theory]
        [InlineData("[{\"Temp\":20.0,\"FanPct\":0.0},{\"Temp\":50.0,\"FanPct\":50.0},{\"Temp\":85.0,\"FanPct\":100.0}]")]
        public void TempAndFanArrayFromJSON(string _testdatainput)
        {
            var tempAndFans = JsonConvert.DeserializeObject<TempAndFan[]>(_testdatainput);
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
        public void PowerConsumptionSerializeToJSON(string _testdatainput)
        {
            PowerConsumption pc = new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000.0 };
            var str = JsonConvert.SerializeObject(pc);
            str.Should().NotBeNull();
            str.Should().Be(_testdatainput);
        }
        [Theory]
        [InlineData("{\"Period\":\"00:01:00\",\"Watts\":1000.0}")]
        public void PowerConsumptionDeSerializeFromJSON(string _testdatainput)
        {
            PowerConsumption powerConsumption = JsonConvert.DeserializeObject<PowerConsumption>(_testdatainput);
            powerConsumption.Should().NotBeNull();
            powerConsumption.Watts.Should().Be(1000);
            powerConsumption.Period.TotalSeconds.Should().Be(60);
        }

        [Theory]
        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
        internal void VideoCardSerializeToJSON(string _testdatainput)
        {
            VideoCardDiscriminatingCharacteristics vcdc = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
    VideoCardMaker.ASUS
    && x.GPUMaker ==
    GPUMaker.NVIDEA)).Single();
            VideoCard videoCard = new VideoCard(vcdc, "10DE 17C8 - 3842", "100.00001.02320.00", false, 1140, 1753, 11.13, 0.8, new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000 }, new TempAndFan() { FanPct = 50.0, Temp = 60 });
            string str = JsonConvert.SerializeObject(videoCard);
            str.Should().NotBeNull();
            str.Should().Be(_testdatainput);
        }

        [Theory]
        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
        internal void VideoCardDeSerializeFromJSON(string _testdatainput)
        {
            VideoCard vc = JsonConvert.DeserializeObject<VideoCard>(_testdatainput);
            vc.Should().NotBeNull();
            vc.DeviceID.Should().Be("10DE 17C8 - 3842");
            vc.BIOSVersion.Should().Be("100.00001.02320.00");
            vc.IsStrapped.Should().Be(false);
            vc.CoreClock.Should().Be(1140);
            vc.MemClock.Should().Be(1753);
            vc.CoreVoltage.Should().Be(11.13);
            vc.PowerLimit.Should().Be(0.8);
            vc.PowerConsumption.Watts.Should().Be(1000);
            vc.PowerConsumption.Period.TotalSeconds.Should().Be(60);
            vc.TempAndFan.Temp.Should().Be(60);
            vc.TempAndFan.FanPct.Should().Be(50);
        }
        [Theory]
        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
        internal void ComputerInventorySerializeToJSON(string _testdatainput)
        {
            ComputerInventory ci = new ComputerInventory();


            string str = JsonConvert.SerializeObject(videoCard);
        str.Should().NotBeNull();
        str.Should().Be(_testdatainput);
    }
}
}
