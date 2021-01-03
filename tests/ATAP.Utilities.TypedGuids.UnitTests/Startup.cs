using System;

namespace ATAP.Utilities.TypedGuids.UnitTests
{
    public class Startup {
      public void ConfigureServices(IServiceCollection services) {
        var _serializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
        var _serializerShimNameSpace = "ATAP.Utilities.Serializer";
        // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
        Assembly.LoadFrom(_serializerShimName)
          .GetTypes()
          .Where(w => w.Namespace == _serializerShimNameSpace && w.IsClass)
          .ToList()
          .ForEach(t => {
            TestOutput
            services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
          });
      }
    }

}
