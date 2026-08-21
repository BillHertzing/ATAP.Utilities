using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Images.Enumerations;
using System.Linq;

namespace ATAP.Utilities.Images.Enumerations.Tests
{

  public static class DefaultEnumerations
  {
    public static IReadOnlyDictionary<string, int> Production { get; } = Enum.GetValues<GPSMetadataEnums>()
      .ToDictionary(value => value.ToString(), value => (int)value);
  }

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
      yield return new object[] { new DefaultEnumerationsTestData("{\"GPSVersion\":0,\"GPSLatitudeRef\":1,\"GPSLatitude\":2,\"GPSLongitudeRef\":3,\"GPSLongitude\":4,\"GPSAltitudeRef\":5,\"GPSAltitude\":6,\"GPSTimeStamp\":7,\"GPSSatellites\":8,\"GPSStatus\":9,\"GPSMeasureMode\":10,\"GPSDOP\":11,\"GPSSpeed\":12,\"GPSTrack\":14,\"GPSImgDirectionRef\":16,\"GPSImgDirection\":17,\"GPSDestLatitudeRef\":19,\"GPSDestLatitude\":20,\"GPSDestLongitudeRef\":21,\"GPSDestLongitude\":22,\"GPSDestBearingRef\":23,\"GPSDestBearing\":24,\"GPSDestDistanceRef\":25,\"GPSDestDistance\":26}") };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultEnumerationsTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
