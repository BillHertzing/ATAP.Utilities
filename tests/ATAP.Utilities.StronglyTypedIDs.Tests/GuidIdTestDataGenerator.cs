using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedID;
using System;


namespace ATAP.Utilities.StronglyTypedID.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class GuidIdTestData
  {
    public IGuidStronglyTypedID GuidId;
    public string SerializedGuidId;

    public GuidIdTestData()
    {
    }

    public GuidIdTestData(IGuidStronglyTypedID guidId, string serializedGuidId)
    {
      GuidId = guidId;
      SerializedGuidId = serializedGuidId ?? throw new ArgumentNullException(nameof(serializedGuidId));
    }
  }

  public class GuidIdTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> GuidIdTestData()
    {
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = (IGuidStronglyTypedID)new GuidStronglyTypedID(Guid.Empty), SerializedGuidId = "00000000-0000-0000-0000-000000000000" } };
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = (IGuidStronglyTypedID)new GuidStronglyTypedID(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedGuidId = "01234567-abcd-9876-cdef-456789abcdef" } };
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = (IGuidStronglyTypedID)new GuidStronglyTypedID(Guid.NewGuid()), SerializedGuidId = "Random, so ignore this property of the test data" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return GuidIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
