using System;
using System.Collections;
using System.Collections.Generic;

namespace ATAP.Utilities.Serializer.DataForTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class IntegerTestData : ATAP.Utilities.Testing.Serialization.TestData<int>
  {
    public IntegerTestData(int objTestData, string serializedTestData) : base(objTestData, serializedTestData) {}
  }

  public class IntegerTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new IntegerTestData[] {new IntegerTestData(-1,"-1")};
      yield return new IntegerTestData[] {new IntegerTestData(0,"0")};
      yield return new IntegerTestData[] {new IntegerTestData(1,"1")};
      yield return new IntegerTestData[] {new IntegerTestData(int.MaxValue, "2147483647") };
      yield return new IntegerTestData[] {new IntegerTestData(int.MinValue, "-2147483648") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
