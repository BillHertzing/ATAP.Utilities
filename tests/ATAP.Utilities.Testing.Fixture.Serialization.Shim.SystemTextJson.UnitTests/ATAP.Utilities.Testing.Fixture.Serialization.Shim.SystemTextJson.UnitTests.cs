using System;
using Moq;
using Xunit;
using Xunit.Abstractions;
using System.Collections.Generic;
using System.Linq;
using FluentAssertions;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.DataForTests;

namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson.UnitTests {

  public partial class UnitTests001 : IClassFixture<Fixture> {
    [Fact]
    void PassingTest() {
      var dummy = "abc";
      dummy.Should().Be("abc");
    }
    [Fact]
    void FailingTest() {
      var dummy = "abc";
      dummy.Should().NotBe("abc");
    }
    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerDeserializeFromJSON(IntegerTestData inTestData) {
      var obj = Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(System.Int32));
      Fixture.Serializer.Deserialize<System.Int32>(inTestData.SerializedTestData).Should().Equals(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(IntegerTestDataGenerator.TestData), MemberType = typeof(IntegerTestDataGenerator))]
    public void IntegerSerializeToJSON(IntegerTestData inTestData) {
      if (Fixture.Serializer == null) { TestOutput.WriteLine("Fixture.Serializer is null"); }
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }

  /*
    [Theory]
    [InlineData("{\"Item1\":\"k1\",\"Item2\":\"k2\"}")]
    void StringInJSONFormatToSimpleTuple(string inTestData)
    {
        (string k1, string k2) r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeSimpleTuple(inTestData);
        Assert.Equal((k1: "k1", k2: "k2"), r);

    }

        [Fact]
        void SimpleTupleToStringInJSONFormat()
        {
            var x = (k1: "k1", k2: "k2");
            var str = ATAP.Utilities.Serializer.InputMethodsForDealingWithJSONFormattedStrings.SerializeSimpleTuple(x);
            Assert.Equal("{\"Item1\":\"k1\",\"Item2\":\"k2\"}", str);

        }

        [Fact]
        void DictionaryTupleToStringInJSONFormat()
        {
            Dictionary<string, double> dict = new Dictionary<string, double>() { { "c1", 10.0 } };
            var x = (k1: "k1", term1: dict);
            var str = InputMethodsForDealingWithJSONFormattedStrings.SerializeDictionaryTuple(x);
            Assert.Equal("{\"Item1\":\"k1\",\"Item2\":{\"c1\":10.0}}", str);

        }

        [Theory]
        [InlineData("{\"Item1\":\"k1\",\"Item2\":{\"c1\":10.0}}")]
        void StringInJSONFormatToDictionaryTuple(string inTestData)
        {
            (string k1, Dictionary<string, double> term1) r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeDictionaryTuple(inTestData);
            var x = (k1: "k1", term1: new Dictionary<string, double>() { { "c1", 10.0 } });
            bool passed = (r.k1 == x.k1) && (r.term1.Count == x.term1.Count);
            // ToDo: figure out a link query that will produce "false" if the keys and values of both dictionaries are not the same
            // bool t = r.Item2.Where(d => x.Item2.ContainsKey(r.Item2.Key) &&
            Assert.True(passed);

        }

        [Fact]
        void ReadOnlyDictionaryTupleToStringInJSONFormat()
        {
            Dictionary<string, double> dict = new Dictionary<string, double>() { { "c1", 10.0 } };
            IReadOnlyDictionary<string, double> readOnlyDict = dict;
            var x = (k1: "k1", term1: readOnlyDict);
            var str = InputMethodsForDealingWithJSONFormattedStrings.SerializeReadOnlyDictionaryTuple(x);
            Assert.Equal("{\"Item1\":\"k1\",\"Item2\":{\"c1\":10.0}}", str);
        }

        [Theory]
        [InlineData("{\"Item1\":\"k1\",\"Item2\":{\"c1\":10.0}}")]
        void StringInJSONFormatToReadOnlyDictionaryTuple(string inTestData)
        {
            (string k1, IReadOnlyDictionary<string, double> term1) r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeReadOnlyDictionaryTuple(inTestData);
            Dictionary<string, double> dict = new Dictionary<string, double>() { { "c1", 10.0 } };
            IReadOnlyDictionary<string, double> readOnlyDict = dict;
            var x = (k1: "k1", term1: readOnlyDict);
            bool passed = (r.k1 == x.k1) && (r.term1.Count == x.term1.Count);
            // ToDo: figure out a link query that will produce "false" if the keys and values of both dictionaries are not the same
            // bool t = r.Item2.Where(d => x.Item2.ContainsKey(r.Item2.Key) &&
            Assert.True(passed);
            // Validate term1 is ReadOnly - uncomment the following for a compile-time error
            // r.term1["new"] = 5.0; ;
        }

        [Fact]
        void CollectionOfSimpleTupleToStringInJSONFormat()
        {
            (string k1, string k2)[] x = new(string k1, string k2)[1] { (k1: "k1", k2: "k2") };
            var str = InputMethodsForDealingWithJSONFormattedStrings.SerializeCollectionOfSimpleTuple(x);
            Assert.Equal("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]", str);

        }

        [Theory]
        [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k2\"}]")]
        void SingleInputStringFormattedAsJSONCollectionOfSimpleTuples(string inTestData)
        {
            IEnumerable<(string k1, string k2)> r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeSingleInputStringFormattedAsJSONCollectionOfSimpleTuples(inTestData);
            Assert.Single(r.ToList());
        }

        [Fact]
        void CollectionOfComplexTupleToStringInJSONFormat()
        {
            (string k1, string k2, IReadOnlyDictionary<string, double> term1)[] _coll = new(string k1, string k2, IReadOnlyDictionary<string, double> term1)[7] {
                (k1: "k1", k2: "k1", term1: new Dictionary<string, double>() { { "A", 11.0 } } as IReadOnlyDictionary<string, double>),
                (k1: "k1", k2: "k2", term1: new Dictionary<string, double>() { { "B", 12.0 } } as IReadOnlyDictionary<string, double>),
                (k1: "k1", k2: "k3", term1: new Dictionary<string, double>() { { "C", 13.0 } } as IReadOnlyDictionary<string, double>),
                (k1: "k1", k2: "k4", term1: new Dictionary<string, double>() { { "D", 14.0 } } as IReadOnlyDictionary<string, double>),
                (k1: "k1", k2: "k5", term1: new Dictionary<string, double>() { { "A", 15.0 }, { "B", 15.1 }, { "C", 15.2 }, { "D", 15.3 } } as IReadOnlyDictionary<string, double>),
                (k1: "k2", k2: "k2", term1: new Dictionary<string, double>() { { "A", 22.0 }, { "B", 22.1 } } as IReadOnlyDictionary<string, double>),
                (k1: "k2", k2: "k3", term1: new Dictionary<string, double>() { { "A", 23.0 }, { "E", 22.4 } } as IReadOnlyDictionary<string, double>)
            };
            var str = InputMethodsForDealingWithJSONFormattedStrings.SerializeCollectionOfComplexTuple(_coll);
            Assert.Equal("[{\"Item1\":\"k1\",\"Item2\":\"k1\",\"Item3\":{\"A\":11.0}},{\"Item1\":\"k1\",\"Item2\":\"k2\",\"Item3\":{\"B\":12.0}},{\"Item1\":\"k1\",\"Item2\":\"k3\",\"Item3\":{\"C\":13.0}},{\"Item1\":\"k1\",\"Item2\":\"k4\",\"Item3\":{\"D\":14.0}},{\"Item1\":\"k1\",\"Item2\":\"k5\",\"Item3\":{\"A\":15.0,\"B\":15.1,\"C\":15.2,\"D\":15.3}},{\"Item1\":\"k2\",\"Item2\":\"k2\",\"Item3\":{\"A\":22.0,\"B\":22.1}},{\"Item1\":\"k2\",\"Item2\":\"k3\",\"Item3\":{\"A\":23.0,\"E\":22.4}}]", str);

        }
        [Theory]
        [InlineData("[{\"Item1\":\"k1\",\"Item2\":\"k1\",\"Item3\":{\"A\":11.0}},{\"Item1\":\"k1\",\"Item2\":\"k2\",\"Item3\":{\"B\":12.0}},{\"Item1\":\"k1\",\"Item2\":\"k3\",\"Item3\":{\"C\":13.0}},{\"Item1\":\"k1\",\"Item2\":\"k4\",\"Item3\":{\"D\":14.0}},{\"Item1\":\"k1\",\"Item2\":\"k5\",\"Item3\":{\"A\":15.0,\"B\":15.1,\"C\":15.2,\"D\":15.3}},{\"Item1\":\"k2\",\"Item2\":\"k2\",\"Item3\":{\"A\":22.0,\"B\":22.1}},{\"Item1\":\"k2\",\"Item2\":\"k3\",\"Item3\":{\"A\":23.0,\"E\":22.4}}]")]
        void SingleInputStringFormattedAsJSONCollectionOfComplexTuples(string inTestData)
        {
            List<(string k1, string k2, IReadOnlyDictionary<string, double> term1)> r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeSingleInputStringFormattedAsJSONCollectionOfComplexTuples(inTestData).ToList<(string k1, string k2, IReadOnlyDictionary<string, double> term1)>();
            r.Should().HaveCount(7);
            r[0].Should().BeOfType(typeof((string k1, string k2, IReadOnlyDictionary<string, double> term1)));
            r[0].k1.Should().Be("k1");
        }
        */
}

