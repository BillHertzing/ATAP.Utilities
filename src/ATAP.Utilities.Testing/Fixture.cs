using System;
using ATAP.Utilities.Serializer;
using ATAP.Utilities.Serializer.Interfaces;
using Ninject;

namespace ATAP.Utilities.Testing
{


  public interface IFixture
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
  public class Fixture : IFixture
  {
    public Fixture()
    {
      Kernel = new StandardKernel(new SerializerInjectionModule());
      Serializer = Kernel.Get<ISerializer>();
    }

    public ISerializer Serializer { get; set; }
    private Ninject.IKernel Kernel { get; set; }

  }
}