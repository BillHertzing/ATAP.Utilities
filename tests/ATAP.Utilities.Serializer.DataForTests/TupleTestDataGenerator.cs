using System;
using System.Collections;
using System.Collections.Generic;

namespace ATAP.Utilities.Serializer.DataForTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class SimpleTupleTestData : ATAP.Utilities.Testing.Serialization.TestData<(string k1, string k2)>
  {
    public SimpleTupleTestData((string k1, string k2) objTestData, string serializedTestData) : base(objTestData, serializedTestData) {}
  }

  public class SimpleTupleTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new SimpleTupleTestData[] {new SimpleTupleTestData(("k1", "k2"),"{\"Item1\":\"k1\",\"Item2\":\"k2\"}")};
      yield return new SimpleTupleTestData[] {new SimpleTupleTestData((k1: "k1", k2: "k2"),"{\"k1\":\"k1\",\"k2\":\"k2\"}")};
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class DictionaryTupleTestData : ATAP.Utilities.Testing.Serialization.TestData<(string k1, Dictionary<string, double> dict)> {
    public DictionaryTupleTestData((string k1, Dictionary<string, double> dict) objTestData, string serializedTestData) : base(objTestData, serializedTestData) { }
  }

  public class DictionaryTupleTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      yield return new DictionaryTupleTestData[] { new DictionaryTupleTestData(("k1", new Dictionary<string, double>() { { "c1", 10.0 } }), "{\"Item1\":\"k1\",\"Item2\":{\"c1\":10.0}}") };
      yield return new DictionaryTupleTestData[] { new DictionaryTupleTestData((k1: "k1", dict: new Dictionary<string, double>() { { "c1", 10.0 } }), "{\"k1\":\"k1\",\"k2\":{\"c1\":10.0}}") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
