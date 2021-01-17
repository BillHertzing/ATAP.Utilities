using System;
using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedIDs;


namespace ATAP.Utilities.StronglyTypedIDs.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class IntIdTestData
  {
    public IntStronglyTypedId IntId;
    public string SerializedIntId;

    public IntIdTestData()
    {
    }

    public IntIdTestData(IntStronglyTypedId intId, string serializedIntId)
    {
      IntId = intId;
      SerializedIntId = serializedIntId ?? throw new ArgumentNullException(nameof(serializedIntId));
    }
  }

  public class IntIdTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> IntIdTestData()
    {
      yield return new IntIdTestData[] { new IntIdTestData { intId = new IntStronglyTypedId(0), SerializedIntId = "0" } };
      yield return new IntIdTestData[] { new IntIdTestData { IntId = new IntStronglyTypedId(1234567), SerializedIntId = "1234567" } };
      yield return new IntIdTestData[] { new IntIdTestData { IntId = new IntStronglyTypedId(new Random().Next()), SerializedIntId = "Random, so ignore this property of the test data" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return IntIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
