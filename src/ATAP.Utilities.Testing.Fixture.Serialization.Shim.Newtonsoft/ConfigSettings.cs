using System;
using System.Collections.Generic;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Testing;

using ATAP.Utilities.Serializer;


namespace ATAP.Utilities.Testing.Fixture.Serialization {
  public partial class SerializationFixtureNewtonsoft : SerializationFixture, ISerializationFixtureNewtonsoft {

    #region Configuration sections: Traverse the inheritance chain and get the various configurationSections from each
    public new (List<Dictionary<string, string>>, List<(string, string)>, List<string>) GetConfigurationSections() {
      // ToDo: Add logger
      // Traverse the inheritance chain, accumulate the config sections at each level
      (List<Dictionary<string, string>> lDCs, List<(string, string)> lSFTs, List<string> lEVPs) = base.GetConfigurationSections();
      // ToDo: add commandline arguments.
      List<Dictionary<string, string>> DefaultConfigurations = new();
      List<(string, string)> SettingsFiles = new();
      List<string> CustomEnvironmentVariablePrefixs = new();
      DefaultConfigurations.Add(DefaultConfiguration.Production);
      SettingsFiles.Add((StringConstants.SettingsFileName, StringConstants.SettingsFileNameSuffix));
      CustomEnvironmentVariablePrefixs.Add(StringConstants.CustomEnvironmentVariablePrefix);
      // ToDo: localize the debug messages
      // logger.Log.Debug("{0} {1}: DefaultConfigurations: {}  SettingsFiles: {} CustomEnvironmentVariablePrefixs: {}", "ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson", "GetConfigurationSections", DateTime.Now.ToString(StringConstantsVA.DATE_FORMAT));
      return (DefaultConfigurations, SettingsFiles, CustomEnvironmentVariablePrefixs);
    }
    #endregion
  }
}
