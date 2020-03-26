using System.Collections.Generic;
using System.Collections;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Philote;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;
using System.Resources;
using System.Text.RegularExpressions;

namespace ATAP.Utilities.Philote.UnitTests {
  public interface IDummyTypeForPhiloteTest { }
  public class DummyTypeForPhiloteTest : IDummyTypeForPhiloteTest {
    public Philote<IDummyTypeForPhiloteTest>? Philote;
  }

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class PhiloteTestData<T> : TestData<IPhilote<T>> {
    public PhiloteTestData(IPhilote<T> objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class PhiloteTestDataGenerator<T> : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      ResourceManager rm = new ResourceManager("ATAP.Utilities.Philote.UnitTests.SerializationStrings", typeof(SerializationStrings).Assembly);
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              //new Philote<T>() ,
               DefaultConfiguration<T>.Production["Generic"],
               Regex.Escape(rm.GetString("SerializedPhilotePart1"))+
              "00000000-0000-0000-0000-000000000000"+
              Regex.Escape(rm.GetString("SerializedPhilotePart2"))) };
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              // new Philote<T>(new Id<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef")),new Dictionary<string, IId<T>>(), new List<ITimeBlock>() ) ,
              DefaultConfiguration<T>.Production["Contrived"],
              Regex.Escape(rm.GetString("SerializedPhilotePart1"))+"01234567-abcd-9876-cdef-456789abcdef" + Regex.Escape(rm.GetString("SerializedPhilotePart2")) ) };
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              new Philote<T>(new Id<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef"))).Now() ,
              Regex.Escape(rm.GetString("SerializedPhilotePart1"))+"[0-9A-Fa-f]{8}-?([0-9A-Fa-f]{4}-?){3}[0-9A-Fa-f]{12}" + Regex.Escape(rm.GetString("SerializedPhilotePart2")) ) };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
