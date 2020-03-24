using System.Collections.Generic;
using System.Collections;

using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Persistence;
using System.Globalization;

namespace ATAP.Utilities.Persistence.UnitTests
{
  
  
    //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
    //public class PersistenceViaIORMTestData : TestData<PersistenceViaIORM>
    //{
    //    public PersistenceViaIORMTestData(IPersistenceViaIORM objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    //    {
    //    }
    //}

    //public class PersistenceViaIORMTestDataGenerator : IEnumerable<object[]>
    //{
    //    public static IEnumerable<object[]> TestData()
    //    {
    //        StringBuilder str = new StringBuilder();
    //        str.Clear();
    //        str.Append(string.Format(CultureInfo.CurrentCulture, $"{ 0}", "abc"));
    //        yield return new PersistenceViaIORMTestData[] {
    //        new PersistenceViaIORMTestData(
    //          new PersistenceViaIORM(
    //          ),
    //          str.ToString())};
    //    }

    //    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    //    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
    //}

    /*
  public class PersistenceViaFileTestData : TestData<PersistenceViaFile>
  {
    public PersistenceViaFileTestData(PersistenceViaFile objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class PersistenceViaFileTestDataGenerator : IEnumerable<object[]>
    {
        public static IEnumerable<object[]> TestData()
        {
            StringBuilder str = new StringBuilder();
            str.Clear();
            str.Append(string.Format(CultureInfo.CurrentCulture, $"{ 0}", "abc"));
            yield return new PersistenceViaFileTestData[] {
            new PersistenceViaFileTestData(
              new PersistenceViaFile(
              ),
              str.ToString())};
        }

        public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
        IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
    }
    */
  }
