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
  public class PersistenceTestData<Tout> where Tout : IInsertResultsAbstract 
  {
    public PersistenceTestData(int numberOfContainers, IEnumerable<IEnumerable<object>> objectsForEachContainer)
    {
      NumberOfContainers = numberOfContainers;
      ObjectsForEachContainer = objectsForEachContainer ?? throw new ArgumentNullException(nameof(objectsForEachContainer));
    }

    public int NumberOfContainers { get; private set; }
    public IEnumerable<IEnumerable<object>> ObjectsForEachContainer { get; private set; }
  }

  public class PersistenceViaFileTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new PersistenceTestData<IInsertViaFileResults>[] {
            new PersistenceTestData<IInsertViaFileResults>(
              1,
              new string[][] { new string[] { "one", "two" } }
      )};
      yield return new PersistenceTestData<IInsertViaFileResults>[] {
            new PersistenceTestData<IInsertViaFileResults>(
              2,
              new string[][] { new string[] { "one", "two" }, new string[] { "fox", "bear", "cat" } }
      )};
    }

    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

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
