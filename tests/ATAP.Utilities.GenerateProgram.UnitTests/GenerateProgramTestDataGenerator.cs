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
using ATAP.Utilities.GenerateProgram;

namespace ATAP.Utilities.GenerateProgram.UnitTests {

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class GenerateProgramTestData : TestData<IGenerateProgram> {
    public GenerateProgramTestData(IGenerateProgram objTestData, string serializedTestData) : base(objTestData, serializedTestData) {
    }
  }

  public class GenerateProgramTestDataGenerator : IEnumerable<object[]> {
    public static IEnumerable<object[]> TestData() {
      ResourceManager rm = new ResourceManager("ATAP.Utilities.GenerateProgram.UnitTests.SerializationStrings", typeof(SerializationStrings).Assembly);
      yield return new GenerateProgramTestData[] {new GenerateProgramTestData(new GenerateProgram(),  Regex.Escape(rm.GetString("SerializedDummyString"))
              //new GenerateProgram() ,
               // DefaultConfiguration.Production["Generic"],
               // Regex.Escape(rm.GetString("SerializedGenerateProgramPart1"))+
              // "00000000-0000-0000-0000-000000000000"+
              // Regex.Escape(rm.GetString("SerializedGenerateProgramPart2"))
              )};
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
