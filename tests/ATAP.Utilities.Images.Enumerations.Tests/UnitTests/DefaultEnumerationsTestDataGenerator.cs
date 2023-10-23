using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Images.Enumerations;

namespace ATAP.Utilities.Images.Enumerations.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DefaultEnumerationsTestData
  {
    public string SerializedDefaultEnumerations;

    public DefaultEnumerationsTestData()
    {
    }

    public DefaultEnumerationsTestData(string serializedDefaultEnumerations)
    {
      SerializedDefaultEnumerations = serializedDefaultEnumerations ?? throw new ArgumentNullException(nameof(serializedDefaultEnumerations));
    }
  }

  public class DefaultEnumerationsTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> DefaultEnumerationsTestData()
    {
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSVersion\":0x0000}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSLatitudeRef\":0x0001}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"ImageDescription\":0x010E}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultEnumerationsTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class DefaultEnumerationsTestData
  {
    public ATAP.Utilities.Images.Enumerations E;

    public DefaultEnumerationsTestData()
    {
    }

    public DefaultEnumerationsTestData(ATAP.Utilities.Images.Enumerations e )
    {
      E = e ?? throw new ArgumentNullException(nameof(e));
    }
  }

  public class DefaultEnumerationsTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> DefaultEnumerationsTestData()
    {
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData {
        E = ATAP.Utilities.Images.Enumerations.ImageDescription,
      }
      };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultEnumerationsTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }


}
