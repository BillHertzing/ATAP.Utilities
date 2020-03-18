using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Testing
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class TestData<T>
  {
    public T ObjTestData;
    public string SerializedTestData;


    public TestData(T objTestData, string serializedTestData)
    {
      ObjTestData = objTestData ?? throw new ArgumentNullException(nameof(objTestData));
      SerializedTestData =  serializedTestData ?? throw new ArgumentNullException(nameof(serializedTestData)) ;
    }

  }
  public class TestDataEn<T>
  {
    public IEnumerable<TestData<T>> E;

    public TestDataEn(IEnumerable<TestData<T>> e)
    {
      E = e ?? throw new ArgumentNullException(nameof(e));
    }
  }
}
