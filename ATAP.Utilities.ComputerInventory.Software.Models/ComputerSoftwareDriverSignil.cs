using System;

namespace ATAP.Utilities.ComputerInventory.Software
{
  [Serializable]
  public class ComputerSoftwareDriverSignil : IComputerSoftwareDriverSignil
  {
    public ComputerSoftwareDriverSignil() : this("generic", ".", "0.0.0")
    {
    }

    public ComputerSoftwareDriverSignil(string name, string path, string version)
    {
      Name = name ?? throw new ArgumentNullException(nameof(name));
      Path = path ?? throw new ArgumentNullException(nameof(path));
      Version = version ?? throw new ArgumentNullException(nameof(version));
    }

    public string Name { get; private set; }
    public string Path { get; private set; }
    public string Version { get; private set; }


  }

}
