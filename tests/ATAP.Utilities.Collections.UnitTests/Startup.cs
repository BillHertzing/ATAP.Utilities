using System;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;

using System.Reflection;
using System.Linq;

namespace ATAP.Utilities.Collection.UnitTests {
  public class Startup {
    public void ConfigureServices(IConfigurationRoot configurationRoot, IServiceCollection services) {
      var _serializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
      var _serializerShimNamespace = "ATAP.Utilities.Serializer";
      // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
      // Assembly.LoadFrom(_serializerShimName)
      //   .GetTypes()
      //   .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
      //   .ToList()
      //   .ForEach(t => {
      //     services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
      //   });
      var serializers = Assembly.LoadFrom(_serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
        .ToList();
    }
  }

}
