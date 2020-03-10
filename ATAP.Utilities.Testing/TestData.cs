using System;


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
    public T[] ObjTestDataArray;
    public string[] SerializedTestDataArray;


    public TestDataEn(T[] objTestDataArray, string[] serializedTestDataArray)
    {
      ObjTestDataArray = objTestDataArray ?? throw new ArgumentNullException(nameof(objTestDataArray));
      //ToDo add test to disallow 0-length enumerable
      SerializedTestDataArray = serializedTestDataArray ?? throw new ArgumentNullException(nameof(serializedTestDataArray));
    }
  }
}
