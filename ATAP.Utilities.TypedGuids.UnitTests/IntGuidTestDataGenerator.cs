using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.TypedGuids;
using System;

namespace ATAP.Utilities.TypedGuids.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class IntGuidTestData
  {
    public Id<int> IntGuid;
    public string SerializedIntGuid;

    public IntGuidTestData()
    {
    }

    public IntGuidTestData(Id<int> intGuid, string serializedIntGuid)
    {
      IntGuid = intGuid;
      SerializedIntGuid = serializedIntGuid ?? throw new ArgumentNullException(nameof(serializedIntGuid));
    }
  }

  public class IntGuidTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> IntGuidTestData()
    {
      yield return new IntGuidTestData[] { new IntGuidTestData { IntGuid = new Id<int>(Guid.Empty), SerializedIntGuid = "\"00000000-0000-0000-0000-000000000000\"" } };
      yield return new IntGuidTestData[] { new IntGuidTestData { IntGuid = new Id<int>(new Guid("F7C2AC22-4CA0-44F0-AC1F-5ECB42596E51")), SerializedIntGuid = "\"f7c2ac22-4ca0-44f0-ac1f-5ecb42596e51\"" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return IntGuidTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
