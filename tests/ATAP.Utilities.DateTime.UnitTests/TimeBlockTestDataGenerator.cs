using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Testing;
using Itenso.TimePeriod;

namespace ATAP.Utilities.DateTime.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class TimeBlockTestData : TestData<TimeBlock>
  {
    public TimeBlockTestData(TimeBlock objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class TimeBlockTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new TimeBlockTestData[] { new TimeBlockTestData(new TimeBlock(), "{\"IsReadOnly\":false,\"IsAnytime\":true,\"IsMoment\":false,\"HasStart\":false,\"Start\":\"\\/Date(-62135596800000-0000)\\/\",\"HasEnd\":false,\"End\":\"\\/Date(253402300800000-0000)\\/\",\"Duration\":\"P3652059D\",\"DurationDescription\":\"3652059 Days 23 Hours 59 Mins\"}") };
      //yield return new TimeBlockTestData[] { new TimeBlockTestData(new TimeBlock(TimeSpan.Zero, new DateTime(2020, 1, 1)), "SerializedTimeBlockInstance") };
      //yield return new TimeBlockTestData[] { new TimeBlockTestData(new TimeBlock(new DateTime(2020, 1, 1), false), "SerializedTimeBlockInstance") };
      //yield return new TimeBlockTestData[] { new TimeBlockTestData(new TimeBlock(new DateTime(2020, 1, 1), true), "SerializedTimeBlockInstance") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }



}
