using System;
using System.ComponentModel;
using Xunit;
using System.Collections.Generic;
using FluentAssertions;
using ATAP.Utilities.Serializer.DataForTests;

using ATAP.Utilities.StronglyTypedIds;


namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.Newtonsoft.UnitTests {

  public partial class UnitTests001 : IClassFixture<Fixture> {
    [Fact]
    void PassingTest() {
      var dummy = "abc";
      dummy.Should().Be("abc");
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
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(SimpleTupleTestDataGenerator.TestData), MemberType = typeof(SimpleTupleTestDataGenerator))]
    public void SimpleTupleDeserializeFromJSON(SimpleTupleTestData inTestData) {
      var obj = Fixture.Serializer.Deserialize<(string k1, string k2)>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof((string k1, string k2)));
      Fixture.Serializer.Deserialize<(string k1, string k2)>(inTestData.SerializedTestData).Should().Equals(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(SimpleTupleTestDataGenerator.TestData), MemberType = typeof(SimpleTupleTestDataGenerator))]
    public void SimpleTupleSerializeToJSON(SimpleTupleTestData inTestData) {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(DictionaryTupleTestDataGenerator.TestData), MemberType = typeof(DictionaryTupleTestDataGenerator))]
    public void DictionaryTupleDeserializeFromJSON(DictionaryTupleTestData inTestData) {
      var obj = Fixture.Serializer.Deserialize<(string k1, Dictionary<string, double> dict)>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof((string k1, Dictionary<string, double> dict)));
      obj.Should().Equals(inTestData.ObjTestData);
        // ToDo: add a helper method to Collections that will compare two dictionaries (including case) for equality
        // ToDo: extend test to compare every element of the two dictionaries
        //(string k1, Dictionary<string, double> term1) r = InputMethodsForDealingWithJSONFormattedStrings.DeSerializeDictionaryTuple(inTestData);
        //var x = (k1: "k1", term1: new Dictionary<string, double>() { { "c1", 10.0 } });
        //bool passed = (r.k1 == x.k1) && (r.term1.Count == x.term1.Count);
        // ToDo: figure out a link query that will produce "false" if the keys and values of both dictionaries are not the same
        // bool t = r.Item2.Where(d => x.Item2.ContainsKey(r.Item2.Key) &&
        //Assert.True(passed);
    }

    [Theory]
    [MemberData(nameof(DictionaryTupleTestDataGenerator.TestData), MemberType = typeof(DictionaryTupleTestDataGenerator))]
    public void DictionaryTupleSerializeToJSON(DictionaryTupleTestData inTestData) {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

    [Fact]
    ///
    public void GuidIdCanConvertTests() {
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedId));
      converterGuid.CanConvertFrom(typeof(string)).Should().Be(true);
      converterGuid.CanConvertFrom(typeof(Guid)).Should().Be(true);
      converterGuid.CanConvertFrom(typeof(int)).Should().Be(false);
    }
    [Fact]
    public void IntIdCanConvertTests() {
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedId));
      converterInt.CanConvertFrom(typeof(string)).Should().Be(true);
      converterInt.CanConvertFrom(typeof(Guid)).Should().Be(false);
      converterInt.CanConvertFrom(typeof(int)).Should().Be(true);
    }
    [Fact]
    public void GuidIdToStringTest() {
      var guidStronglyTypedId = new GuidStronglyTypedId();
      guidStronglyTypedId.ToString().Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdTypeConverterTestDataGenerator<Guid>.StronglyTypedIdTypeConverterTestData), MemberType = typeof(StronglyTypedIdTypeConverterTestDataGenerator<Guid>))]
    public void GuidIdConvertFromString(StronglyTypedIdTypeConverterTestData<Guid> inTestData) {
      if (inTestData == null) { throw new ArgumentNullException(nameof(inTestData)); }
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedId));
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        //var stronglyTypedId = SerializationSystemTextJsonFixture.Serializer.Deserialize<GuidStronglyTypedId>(inTestData.SerializedTestData);
        var stronglyTypedId = converterGuid.ConvertFrom(inTestData.SerializedTestData);
        stronglyTypedId.Should().BeOfType(typeof(GuidStronglyTypedId));
        // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
        stronglyTypedId.Should().Be(inTestData.InstanceTestData);
      }
      else {
        // No data for random guids
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdTypeConverterTestDataGenerator<Guid>.StronglyTypedIdTypeConverterTestData), MemberType = typeof(StronglyTypedIdTypeConverterTestDataGenerator<Guid>))]
    public void GuidIdConvertToString(StronglyTypedIdTypeConverterTestData<Guid> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException(nameof(inTestData)); }
      var converterGuid = TypeDescriptor.GetConverter(typeof(GuidStronglyTypedId));
      // GUIDS are random, two sets of test data have fixed, non-random guids, the rest are random
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        converterGuid.ConvertTo(inTestData.InstanceTestData, typeof(string)).Should().Be(inTestData.SerializedTestData);
      }
      else {
        ((string)converterGuid.ConvertTo(inTestData.InstanceTestData, typeof(string))).Should().MatchRegex("^[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}$");
      }
    }

    [Fact]
    public void IntIdToStringTest() {
      var intStronglyTypedId = new IntStronglyTypedId();
      intStronglyTypedId.ToString().Should().MatchRegex("^\\d+$");
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdTypeConverterTestDataGenerator<int>.StronglyTypedIdTypeConverterTestData), MemberType = typeof(StronglyTypedIdTypeConverterTestDataGenerator<int>))]
    public void IntIdConvertFromString(StronglyTypedIdTypeConverterTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException(nameof(inTestData)); }
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedId));
      if (inTestData.SerializedTestData.StartsWith("0000", System.StringComparison.CurrentCulture) || inTestData.SerializedTestData.StartsWith("01234", System.StringComparison.CurrentCulture)) {
        //var stronglyTypedId = SerializationSystemTextJsonFixture.Serializer.Deserialize<IntStronglyTypedId>(inTestData.SerializedTestData);
        var stronglyTypedId = converterInt.ConvertFrom(inTestData.SerializedTestData);
        stronglyTypedId.Should().BeOfType(typeof(IntStronglyTypedId));
        // two sets of test data have fixed, non-random Integers, the rest are random
        stronglyTypedId.Should().Be(inTestData.InstanceTestData);
      }
      else {
        // No data for random Integers
      }
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdTypeConverterTestDataGenerator<int>.StronglyTypedIdTypeConverterTestData), MemberType = typeof(StronglyTypedIdTypeConverterTestDataGenerator<int>))]
    public void IntIdConvertToString(StronglyTypedIdTypeConverterTestData<int> inTestData) {
      // ToDo low priority localize the unit test's exception's message
      if (inTestData == null) { throw new ArgumentNullException(nameof(inTestData)); }
      var converterInt = TypeDescriptor.GetConverter(typeof(IntStronglyTypedId));
      // two sets of test data have fixed, non-random Integers, the rest are random
      if (inTestData.SerializedTestData.Equals("0") || inTestData.SerializedTestData.Equals("1234567")) {
        converterInt.ConvertTo(inTestData.InstanceTestData, typeof(string)).Should().Be(inTestData.SerializedTestData);
      }
      else {
        // No test available for random integer
      }
    }
  }

  /*

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

