using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedIDs;
using System;


namespace ATAP.Utilities.StronglyTypedIDs.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class IntGuidTestData
  {
    public IdAsStruct<int> IntGuid;
    public string SerializedIntGuid;

    public IntGuidTestData()
    {
    }

    public IntGuidTestData(IdAsStruct<int> intGuid, string serializedIntGuid)
    {
      IntGuid = intGuid;
      SerializedIntGuid = serializedIntGuid ?? throw new ArgumentNullException(nameof(serializedIntGuid));
    }
  }

  public class IntGuidTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> IntGuidTestData()
    {
      yield return new IntGuidTestData[] { new IntGuidTestData { IntGuid = new IdAsStruct<int>(Guid.Empty), SerializedIntGuid = "00000000-0000-0000-0000-000000000000" } };
      yield return new IntGuidTestData[] { new IntGuidTestData { IntGuid = new IdAsStruct<int>(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedIntGuid = "01234567-abcd-9876-cdef-456789abcdef" } };
      yield return new IntGuidTestData[] { new IntGuidTestData { IntGuid = new IdAsStruct<int>(Guid.NewGuid()), SerializedIntGuid = "Random, so ignore this property of the test data" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return IntGuidTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
