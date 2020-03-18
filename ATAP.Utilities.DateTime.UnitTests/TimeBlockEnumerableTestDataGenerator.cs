using System.Collections.Generic;
using System.Collections;
using System;
using ATAP.Utilities.Testing;
using Itenso.TimePeriod;

namespace ATAP.Utilities.DateTime.UnitTests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class TimeBlockEnumerableTestData : TestDataEn<ITimeBlock>
  {
    public TimeBlockEnumerableTestData(IEnumerable<TestData<ITimeBlock>> e) : base(e)
    {
    }
  }

  public class TimeBlockEnumerableTestDataGenerator : IEnumerable<object[]>
  {
    public static TimeBlock timeBlockStaticDefault = new TimeBlock();
    public static TimeBlock timeBlockStaticMilleniumMoment = new TimeBlock(new System.DateTime(2020, 1, 1));
    public static TimeBlock timeBlockStaticMilleniumFirstHour = new TimeBlock(new System.DateTime(2020, 1, 1), new System.DateTime(2020, 1, 1,1,0,0));
    public static TestData<ITimeBlock> timeBlockTestDataStaticDefault = new TestData<ITimeBlock>(timeBlockStaticDefault, "{\"IsReadOnly\":false,\"IsAnytime\":true,\"IsMoment\":false,\"HasStart\":false,\"Start\":\"\\/Date(-62135596800000-0000)\\/\",\"HasEnd\":false,\"End\":\"\\/Date(253402300800000-0000)\\/\",\"Duration\":\"P3652059D\",\"DurationDescription\":\"3652059 Days 23 Hours 59 Mins\"}");
    public static TestData<ITimeBlock> timeBlockTestDataStaticMilleniumMoment = new TestData<ITimeBlock>(timeBlockStaticMilleniumMoment, "{\"IsReadOnly\":false,\"IsAnytime\":false,\"IsMoment\":true,\"HasStart\":true,\"Start\":\"\\/Date(1577862000000-0000)\\/\",\"HasEnd\":true,\"End\":\"\\/Date(1577862000000-0000)\\/\",\"Duration\":\"PT0S\",\"DurationDescription\":\"\"}");
    public static TestData<ITimeBlock> timeBlockTestDataStaticMilleniumFirstHour = new TestData<ITimeBlock>(timeBlockStaticMilleniumFirstHour, "{\"IsReadOnly\":false,\"IsAnytime\":false,\"IsMoment\":false,\"HasStart\":true,\"Start\":\"\\/Date(1577862000000-0000)\\/\",\"HasEnd\":true,\"End\":\"\\/Date(1577865600000-0000)\\/\",\"Duration\":\"PT1H\",\"DurationDescription\":\"1 Hour\"}");
    //public static List<ITimeBlock> timeBlockListDefault = new List<ITimeBlock>() { timeBlockDefault };
    //public static TimeBlockEnumerableTestData = new List<TestData<ITimeBlock>>() {new TestData<ITimeBlock>(new TimeBlock(),"xyz")}

    public static IEnumerable<object[]> TestData()
    {
      // An empty list
      yield return new TimeBlockEnumerableTestData[] { new TimeBlockEnumerableTestData(new List<TestData<ITimeBlock>>()) };
      yield return new TimeBlockEnumerableTestData[] { new TimeBlockEnumerableTestData(new List<TestData<ITimeBlock>>() { timeBlockTestDataStaticDefault }) };
      yield return new TimeBlockEnumerableTestData[] { new TimeBlockEnumerableTestData(new List<TestData<ITimeBlock>>() { timeBlockTestDataStaticMilleniumMoment, timeBlockTestDataStaticMilleniumFirstHour }) };
      //yield return new TimeBlockEnumerableTestData[] { new TimeBlockTestData(new TimeBlock(TimeSpan.Zero, new DateTime(2020, 1, 1)), "SerializedTimeBlockInstance") };
      //yield return new TimeBlockEnumerableTestData[] { new TimeBlockTestData(new TimeBlock(new DateTime(2020, 1, 1), false), "SerializedTimeBlockInstance") };
      //yield return new TimeBlockEnumerableTestData[] { new TimeBlockTestData(new TimeBlock(new DateTime(2020, 1, 1), true), "SerializedTimeBlockInstance") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
