
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using ATAP.Utilities.Philote;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using System.Collections.Generic;
using System;
using System.Diagnostics.CodeAnalysis;

//using GenerateProgram;

//  using EnvDTE;
//    using System.IO;
//    using Microsoft.VisualStudio.TextTemplating;

namespace GenerateProgram.UnitTests {

  public partial class GPTests : IClassFixture<GPFixture> {
    //[Theory]
    //[InlineData(new GUsing(), @"../../src/services/generateprogram/GenerateProgramSettings.Development.json")]
    //[FactAttribute]
    //public void TUsingTest() {
    //  // Arrange
    //  <#@ assembly name="EnvDTE" #>
    //  DTE dte = ((IServiceProvider)this.Host).GetCOMService(typeof(DTE)) as DTE;

    //  IServiceProvider serviceProvider = dte; // or dslDiagram.Store, for example
    //  // Get the text template service:
    //  ITextTemplating t4 = serviceProvider.GetService(typeof(STextTemplating)) as ITextTemplating;
    //  ITextTemplatingSessionHost host = t4 as ITextTemplatingSessionHost;
    //  // Create a Session in which to pass parameters:
    //  host.Session = host.CreateSession();
    //  // Add parameter values to the Session:
    //  session["TimesToRepeat"] = 5;
    //  // Process a text template:
    //  string result = t4.ProcessTemplate("MyTemplateFile.t4",
    //    System.IO.File.ReadAllText("MyTemplateFile.t4"));
    //  GUsing u = new GUsing() { GName = "TestUsing1" };
    //  var templateClass = new GenerateProgram. .TUsing();
    //  // Load Configuration information from inTestData
    //  // Override output directory to testing temp dir
    //  // Act
    //  var result = templateClass.TransformText();
    //  // Assert
    //  //obj.Should().BeOfType(typeof(GenerateProgram));
    //  //Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    //  //Fixture.Result.Should().Be(False);
    //}

    //[FactAttribute]
    //public void TGeneratePropertyTest() {
    //  // Arrange
    //  GProperty p = new GProperty() {GAccessability = "public", GName = "TestProperty1" ,GAccessors = "{get; set;}"};
    //  var templateClass = new ATAP.Utilities.GenerateProgram.UnitTests.TPropertyTest();
    //  var x = new ATAP.Utilities.GenerateProgram.UnitTests.TPropertyTest();
    //  // Load Configuration information from inTestData
    //  // Override output directory to testing temp dir
    //  // Act
    //  var result = templateClass.TransformText();
    //  // Assert
    //  //obj.Should().BeOfType(typeof(GenerateProgram));
    //  //Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    //  //Fixture.Result.Should().Be(False);
    //}

  }
  public partial class SerializationUnitTests001 : IClassFixture<SerializationFixture>
  {


    //[Theory]
    //[MemberData(nameof(GenerateProgramTestDataGenerator.TestData), MemberType = typeof(GenerateProgramTestDataGenerator))]
    //public void GenerateProgramDeserializeFromJSON(GenerateProgramTestData inTestData)
    //{
    //  var obj = Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData);
    //  // ToDo Figure out how to assert that a type implements IEnuerable<T>
    //  //obj.Should().BeOfType(typeof(GenerateProgram));
    //  Fixture.Serializer.Deserialize<GenerateProgram>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    //}

    //[Theory]
    //[MemberData(nameof(GenerateProgramTestDataGenerator.TestData), MemberType = typeof(GenerateProgramTestDataGenerator))]
    //public void GenerateProgramSerializeToJSON(GenerateProgramTestData inTestData)
    //{
    //  Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().MatchRegex(inTestData.SerializedTestData);
    //}
  }
}
