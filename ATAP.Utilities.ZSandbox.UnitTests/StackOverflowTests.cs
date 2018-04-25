    using System.ComponentModel;
    using FluentAssertions;
    using Xunit;
    using YamlDotNet.Serialization;

    namespace Utilities.ComputerInventory {
        public class CPU {
            private CPUMaker cPUMaker;
        public CPU()         {        }
        public CPU(CPUMaker cPUMaker = CPUMaker.Generic) {
                this.cPUMaker = cPUMaker;
            }
        //public CPUMaker CPUMaker => cPUMaker;
        public CPUMaker CPUMaker { get { return cPUMaker; } private set => cPUMaker = value; }
        public override int GetHashCode()
        {
            return cPUMaker.GetHashCode();
        }
    }

    public enum CPUMaker {
            [Description("Generic")]
            Generic,
            [Description("Intel")]
            Intel,
            [Description("AMD")]
            AMD
        }
    }
    namespace Utilities.ComputerInventory.UnitTests {
        public class ComputerInventoryUnitTests001 {
            [Fact]
            public void CPUDeserializeFromYAMLSO() {
                Serializer serializer = new SerializerBuilder().Build();
                Deserializer deserializer = new DeserializerBuilder().Build();
                CPU cPU = new CPU(CPUMaker.Intel);
            string str = serializer.Serialize(cPU);
                CPU cPUAfterRoundTrip = deserializer.Deserialize<CPU>(serializer.Serialize(cPU));
                cPUAfterRoundTrip.Should().Be(cPU);
            }
        }
    }