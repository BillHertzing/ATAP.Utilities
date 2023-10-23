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
      // # This should list every value of the enumeration
      // ToDo: add the ability to create enumeration test data based on the string definitions in the class's declaration
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSVersion\":0x0000}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSLatitudeRef\":0x0001}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSLatitude\":0x0002}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSLongitudeRef\":0x0003}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSLongitude\":0x0004}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSAltitudeRef\":0x0005}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSAltitude\":0x0006}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSTimeStamp\":0x0007}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSSatellites\":0x0008}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSStatus\":0x0009}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSMeasureMode\":0x000A}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDOP\":0x000B}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSSpeed\":0x000C}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSTrack\":0x000E}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSImgDirectionRef\":0x0010}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSImgDirection\":0x0011}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSMapDatum\":0x0012}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestLatitudeRef\":0x0013}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestLatitude\":0x0014}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"PSDestLongitudeRef\":0x0015}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestLongitude\":0x0016}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestBearingRef\":0x0017}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestBearing\":0x0018}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestDistanceRef\":0x0019}" } };
      yield return new DefaultEnumerationsTestData[] { new DefaultEnumerationsTestData { SerializedDefaultEnumerations = "{\"GPSDestDistance\":0x001A}" } };
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
        E = ATAP.Utilities.Images.Enumerations.GPSVersion,
        E = ATAP.Utilities.Images.Enumerations.GPSLatitudeRef,
        E = ATAP.Utilities.Images.Enumerations.ImageDescription,
      }
      };
    }
    public IEnumerator<object[]> GetEnumerator() { return DefaultEnumerationsTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }


}
