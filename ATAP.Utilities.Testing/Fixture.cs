using System;
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
      Bind<ISerializer>().To<ATAP.Utilities.Serializer.Serializer>();
    }
  }
  public class Fixture :  IFixture
  {
    public Fixture()
    {
      Ninject.IKernel kernel = new StandardKernel(new SerializerInjectionModule());
      Serializer = kernel.Get<ISerializer>();
    }

    public ISerializer Serializer { get; set; }


  }
}
