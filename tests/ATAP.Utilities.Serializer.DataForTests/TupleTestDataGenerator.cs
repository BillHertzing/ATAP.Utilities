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
}
