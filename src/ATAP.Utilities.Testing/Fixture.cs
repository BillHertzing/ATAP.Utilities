using System;
using ATAP.Utilities.Serializer;
using Ninject;

namespace ATAP.Utilities.Testing
{


  public interface IDiFixture
  {
    ISerializer Serializer { get; set; }
  }

  public class SerializerInjectionModule : Ninject.Modules.NinjectModule
  {
    public override void Load()
    {
      // ToDo make this lazy ISerializer t = ATAP.Utilities.Serializer.SerializerLoader.LoadSerializerFromAssembly();
      Bind<ISerializer>().To<Serializer.Serializer>();
    }
  }
  public class DiFixture : IDiFixture
  {
    public DiFixture()
    {
      Kernel = new StandardKernel(new SerializerInjectionModule());
      Serializer = Kernel.Get<ISerializer>();
    }

    public ISerializer Serializer { get; set; }
    private Ninject.IKernel Kernel { get; set; }

  }
}
