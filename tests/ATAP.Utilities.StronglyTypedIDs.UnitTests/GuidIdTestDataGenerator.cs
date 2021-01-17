using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.StronglyTypedIDs;
using System;


namespace ATAP.Utilities.StronglyTypedIDs.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class GuidIdTestData
  {
    public IGuidStronglyTypedId GuidId;
    public string SerializedGuidId;

    public GuidIdTestData()
    {
    }

    public GuidIdTestData(IGuidStronglyTypedId GuidId, string serializedGuidId)
    {
      GuidId = GuidId;
      SerializedGuidId = serializedGuidId ?? throw new ArgumentNullException(nameof(serializedGuidId));
    }
  }

  public class GuidIdTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> GuidIdTestData()
    {
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = new GuidStronglyTypedId(Guid.Empty), SerializedGuidId = "00000000-0000-0000-0000-000000000000" } };
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = new GuidStronglyTypedId(new Guid("01234567-abcd-9876-cdef-456789abcdef")), SerializedGuidId = "01234567-abcd-9876-cdef-456789abcdef" } };
      yield return new GuidIdTestData[] { new GuidIdTestData { GuidId = new GuidStronglyTypedId(Guid.NewGuid()), SerializedGuidId = "Random, so ignore this property of the test data" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return GuidIdTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
