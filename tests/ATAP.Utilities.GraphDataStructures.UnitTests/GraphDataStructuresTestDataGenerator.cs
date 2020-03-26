using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Testing;
using ATAP.Utilities.GraphDataStructures;

namespace ATAP.Utilities.GraphDataStructures.UnitTests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class SerializationTestData : TestData<Vertex<int>> {
    public SerializationTestData(Vertex<int> objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class GraphDataStructuresSerializationTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(1), "1") };
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(2), "2") };
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(3), "2") };
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(default), "0") };
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(Int32.MinValue), "-32767") };
      yield return new SerializationTestData[] { new SerializationTestData(new Vertex<int>(Int32.MaxValue), "4096723") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
