using System.Collections.Generic;
using System.Collections;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Philote;
using ATAP.Utilities.TypedGuids;
using Itenso.TimePeriod;

namespace ATAP.Utilities.Philote.UnitTests
{
  public interface IDummyTypeForPhiloteTest { }
  public class DummyTypeForPhiloteTest : IDummyTypeForPhiloteTest
  {
    public Philote<IDummyTypeForPhiloteTest>? Philote;
  }

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class PhiloteTestData<T> : TestData<IPhilote<T>>
  {
    public PhiloteTestData(IPhilote<T> objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class PhiloteTestDataGenerator<T> : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              //new Philote<T>() ,
               DefaultConfiguration<T>.Production["Generic"],
              "{\"ID\":\"00000000-0000-0000-0000-000000000000\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}" ) };
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              // new Philote<T>(new Id<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef")),new Dictionary<string, IId<T>>(), new List<ITimeBlock>() ) ,
              DefaultConfiguration<T>.Production["Contrived"],
              "{\"ID\":\"01234567-abcd-9876-cdef-456789abcdef\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}" ) };
      yield return new PhiloteTestData<T>[] {new PhiloteTestData<T>(
              new Philote<T>(new Id<T>(new Guid("01234567-abcd-9876-cdef-456789abcdef"))).Now() ,
              "{\"ID\":\"00000000-0000-0000-0000-000000000000\",\"AdditionalIDs\":{},\"TimeBlocks\":[]}" ) };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
