
using ATAP.Utilities.Persistence;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using static FluentAssertions.FluentActions;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Persistence.UnitTests
{
  public partial class SerializationUnitTests001 : IClassFixture<SerializationFixture>
  {

    // // Common constructor method for the InsertViaFileFunc used in these tests
    // // Uses the structures setup by the SetupViaFileFuncBuilder
    // Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> InsertViaFileFuncBuilder()
    // {
      // Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults> ret = new Func<IInsertViaFileData, ISetupViaFileResults, InsertViaFileResults>((insertData, setupResults) =>
      // {
        // int numberOfFiles = insertData.DataToInsert[0].Length;
// #if DEBUG
        // TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
// #endif
        // int numberOfStreamWriters = setupResults.StreamWriters.Length;
// #if DEBUG
        // TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
// #endif
        // for (var i = 0; i < numberOfFiles; i++)
        // {
          // foreach (string str in insertData.DataToInsert[i])
          // {
            // //await setupResults.StreamWriters[i].WriteLineAsync(str);
            // setupResults.StreamWriters[i].WriteLine(str);
          // }
        // }
        // return new InsertViaFileResults(true);

      // });
      // return ret;
    // }


    [Xunit.Fact]
    void VerifySetupViaFileDataThrowsOnEmptyIEnumerable()
    {
      string[] filePaths = new string[0];
      Invoking(() => new SetupViaFileData(filePaths))
    .Should().Throw<InvalidDataException>()
    .WithMessage("filePaths has no elements");
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    void VerifySetupCreatesCorrectNumberOfResultElements(int inTestData)
    {
      // Create a number of temporary files, empty, and put their names in filePaths
      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }

      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));

      setupResults.Success.Should().Be(true);
      setupResults.FileStreams.Length.Should().Be(inTestData);
      setupResults.StreamWriters.Length.Should().Be(inTestData);
      setupResults.Dispose();
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    void VerifyDispose(int inTestData)
    {
      // Create a number of temporary files, empty, and put their names in filePaths
      var temporaryFiles = new TemporaryFile[inTestData];
      var filePaths = new string[inTestData];
      for (int i = 0; i < inTestData; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));
      setupResults.Dispose();
      for (int i = 0; i < inTestData; i++)
      {
        // Any access to a disposed object should result in an exception
        Invoking(() => { setupResults.StreamWriters[i].Write("Should Throw ObjectDisposedException"); })
          .Should().Throw<ObjectDisposedException>()
          .WithMessage("Cannot write to a closed TextWriter.*");
        Invoking(() => { var fsl = setupResults.FileStreams[i].Length; })
          .Should().Throw<ObjectDisposedException>()
          .WithMessage("Cannot access a closed file.");
      }
    }

    [Theory]
    [MemberData(nameof(PersistenceViaFileTestDataGenerator.TestData), MemberType = typeof(PersistenceViaFileTestDataGenerator))]

    void VerifyInsert(PersistenceTestData<IInsertViaFileResults> inTestData)
    {
      // Create a number of temporary files, empty, and put their names in filePaths
      var temporaryFiles = new TemporaryFile[inTestData.NumberOfContainers];
      var filePaths = new string[inTestData.NumberOfContainers];
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }

      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));
      setupResults.Success.Should().Be(true);

      var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) =>
      {
        int numberOfFiles = insertData.ToArray().Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
#endif
        int numberOfStreamWriters = setupResults.StreamWriters.Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
#endif
        for (var i = 0; i < numberOfFiles; i++)
        {
          foreach (string str in insertData.ToArray()[i])
          {
            //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
            //ToDo: exception handling
            setupResults.StreamWriters[i].WriteLine(str);
#if DEBUG
            TestOutput.WriteLine($"writing {str} to file {i}");
#endif
          }
        }
        return new InsertViaFileResults(true);
      });
      //IEnumerable<IEnumerable<object>> dataToInsert = inTestData.ObjectsForEachContainer;
      IEnumerable<object>[] containersToInsert = inTestData.ObjectsForEachContainer.ToArray();
      string[][] dataToInsert = new string[containersToInsert.Count()][];
      for (var i = 0; i < containersToInsert.Count(); i++)
      {
        object[] objArray = containersToInsert[i].ToArray();
        //string[] strArray =  as string[];

        dataToInsert[i] = objArray.Select(x => x.ToString()) as string[];
      }

      var insertResults = insertFunc(dataToInsert);
      insertResults.Success.Should().Be(true);
      setupResults.Dispose();
      long CountLinesLINQ(FileInfo file) => File.ReadLines(file.FullName).Count(); // replace with a File Utility https://www.nimaara.com/, or pull in his library
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        CountLinesLINQ(temporaryFiles[i].FileInfo).Should().Be(inTestData.ObjectsForEachContainer.ToArray()[i].Count());
      }
    }

    [Theory]
    [MemberData(nameof(PersistenceViaFileTestDataGenerator.TestData), MemberType = typeof(PersistenceViaFileTestDataGenerator))]
    void VerifyInsertClosureOverSetupResultsUsingIInsertViaFileResults(PersistenceTestData<IInsertViaFileResults> inTestData)
    {
      // Create a number of temporary files, empty, and put their names in filePaths
      var temporaryFiles = new TemporaryFile[inTestData.NumberOfContainers];
      var filePaths = new string[inTestData.NumberOfContainers];
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      }
      var setupData = new SetupViaFileData(filePaths);
      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));
      // Validate the results are as expected
      setupResults.Success.Should().Be(true);
      setupResults.FileStreams.Length.Should().Be(inTestData.NumberOfContainers);
      setupResults.StreamWriters.Length.Should().Be(inTestData.NumberOfContainers);
      // Create an insertFunc that references the local variable setupResults, closing over it
      var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) =>
        {
          int numberOfFiles = insertData.ToArray().Length;
#if DEBUG
          TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
#endif
          int numberOfStreamWriters = setupResults.StreamWriters.Length;
#if DEBUG
          TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
#endif
          for (var i = 0; i < numberOfFiles; i++)
          {
            foreach (string str in insertData.ToArray()[i])
            {
              //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
              //ToDo: exception handling
              setupResults.StreamWriters[i].WriteLine(str);
#if DEBUG
              TestOutput.WriteLine($"writing {str} to file {i}");
#endif
            }
          }
          return new InsertViaFileResults(true);
        });

      Persistence<IInsertViaFileResults> persistence = new Persistence<IInsertViaFileResults>(insertFunc);
      // Create a simple function whose only tasks is to write some data to the persistence files, and return
      Action<IPersistence<IInsertViaFileResults>> SimpleAction = new Action<IPersistence<IInsertViaFileResults>>((persistence) =>
      {
        // Insert the data to the persistence mechanism
        var insertResults = persistence.InsertFunc(inTestData.ObjectsForEachContainer);
        insertResults.Success.Should().Be(true); // Only inside of tests
      });

      // Execute the SimpleAction, which at completion exits the closure over setupResults
      SimpleAction(persistence);

      // Dispose of the persistence setupResults
      setupResults.Dispose();

      // did we get the data we expected
      long CountLinesLINQ(FileInfo file) => File.ReadLines(file.FullName).Count();
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        CountLinesLINQ(temporaryFiles[i].FileInfo).Should().Be(inTestData.ObjectsForEachContainer.ToArray()[i].Count());
      }
    }

    [Theory]
    [MemberData(nameof(PersistenceViaFileTestDataGenerator.TestData), MemberType = typeof(PersistenceViaFileTestDataGenerator))]
    void VerifyInsertWhenUsingIInsertResultsAbstract(PersistenceTestData<IInsertViaFileResults> inTestData)
    {
      // Create a number of temporary files, empty, and put their names in filePaths
      var temporaryFiles = new TemporaryFile[inTestData.NumberOfContainers];
      var filePaths = new string[inTestData.NumberOfContainers];
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        temporaryFiles[i] = new TemporaryFile().CreateTemporaryFileEmpty();
        filePaths[i] = temporaryFiles[i].FileInfo.FullName;
      };

      // Call the SetupViaFileFuncBuilder here, execute the Func that comes back, with filePaths as the argument
      var setupResults = ATAP.Utilities.Persistence.StaticExtensions.SetupViaFileFuncBuilder()(new SetupViaFileData(filePaths));
      // Validate the results are as expected
      setupResults.Success.Should().Be(true);
      setupResults.FileStreams.Length.Should().Be(inTestData.NumberOfContainers);
      setupResults.StreamWriters.Length.Should().Be(inTestData.NumberOfContainers);
      // Create an insertFunc that references the local variable setupResults, closing over it
      var insertFunc = new Func<IEnumerable<IEnumerable<object>>, IInsertViaFileResults>((insertData) =>
      {
        int numberOfFiles = insertData.ToArray().Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfFiles} arrays of data to write");
#endif
        int numberOfStreamWriters = setupResults.StreamWriters.Length;
#if DEBUG
        TestOutput.WriteLine($"Got {numberOfStreamWriters} streamwriters to write to");
#endif
        for (var i = 0; i < numberOfFiles; i++)
        {
          foreach (string str in insertData.ToArray()[i])
          {
            //ToDo: add async versions await setupResults.StreamWriters[i].WriteLineAsync(str);
            //ToDo: exception handling
            setupResults.StreamWriters[i].WriteLine(str);
#if DEBUG
            TestOutput.WriteLine($"writing {str} to file {i}");
#endif
          }
        }
        return new InsertViaFileResults(true);
      });

      Persistence<IInsertResultsAbstract> persistence = new Persistence<IInsertResultsAbstract>(insertFunc);
      // Create a simple function whose only tasks is to write some data to the persistence files, and return
      Action<IPersistence<IInsertResultsAbstract>> SimpleAction = new Action<IPersistence<IInsertResultsAbstract>>((persistence) =>
      {
        // Insert the data to the persistence mechanism
        var insertResults = persistence.InsertFunc(inTestData.ObjectsForEachContainer);
        insertResults.Success.Should().Be(true); // Only inside of tests
      });

      // Execute the SimpleAction, which at completion exits the closure over setupResults
      SimpleAction(persistence);

      // Dispose of the persistence setupResults
      setupResults.Dispose();

      // did we get the data we expected
      long CountLinesLINQ(FileInfo file) => File.ReadLines(file.FullName).Count();
      for (int i = 0; i < inTestData.NumberOfContainers; i++)
      {
        CountLinesLINQ(temporaryFiles[i].FileInfo).Should().Be(inTestData.ObjectsForEachContainer.ToArray()[i].Count());
      }
    }
  }
}



