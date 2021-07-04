using System;
using System.IO;
using System.Reflection;


namespace ATAP.Utilities.Testing {

  /// <summary>
  /// A base Test Fixture Interface for the class from which all the ATAP.Utilities.Testing Test Fixture derive
  /// </summary>
  public interface ISimpleFixture {
    public String InitialStartupDirectory { get; }
    public String LoadedFromDirectory { get; }
  }

  /// <summary>
  /// A base Test Fixture from which all the ATAP.Utilities.Testing Test Fixture derive
  /// </summary>
  public class SimpleFixture : ISimpleFixture {
    public String InitialStartupDirectory { get; }
    public String LoadedFromDirectory { get; }

    public SimpleFixture() : base() {
      #region initialStartup and loadedFrom directories
      // When running as Unit or Integration test, locally or in a CI pipeline, it is very possible that there may be local (to the initial startup directory) configuration files to load
      // get the initial startup directory
      // get the directory where the executing assembly (usually .exe) and possibly machine-wide configuration files are installed to.
      InitialStartupDirectory = Directory.GetCurrentDirectory(); //ToDo: Catch exceptions
      LoadedFromDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location); //ToDo: Catch exceptions
      #endregion
    }
  }
}
