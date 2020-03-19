using ATAP.Utilities.Philote;
using System;
using System.Collections.Generic;
using System.IO;



namespace ATAP.Utilities.ComputerInventory.Hardware
{


  public class FSEntityAbstract : IFSEntityAbstract
  {
    public FSEntityAbstract() : this("", new Philote.Philote<IFSEntityAbstract>().Now(), null) { }
    public FSEntityAbstract(string path) : this(path, new Philote.Philote<IFSEntityAbstract>().Now(), null) { }
    public FSEntityAbstract(string path, IPhilote<IFSEntityAbstract> philote) : this(path, philote, null) { }
    public FSEntityAbstract(string path, IPhilote<IFSEntityAbstract> philote, Exception? exception)
    {
      Path = path ?? throw new ArgumentNullException(nameof(path));
      Philote = philote ?? throw new ArgumentNullException(nameof(philote));
      Exception = exception;
    }

    public string Path { get; set; }
    public IPhilote<IFSEntityAbstract> Philote { get; set; }
    public Exception? Exception { get; set; }
  }


  public class FSEntityDirectory : FSEntityAbstract, IFSEntityDirectory
  {
    public FSEntityDirectory(string path, DirectoryInfo? directoryInfo, IPhilote<IFSEntityAbstract> philote, Exception? exception) : base(path, philote, exception)
    {
      DirectoryInfo = directoryInfo;
    }
    public FSEntityDirectory(string path) : this(path, null, new Philote.Philote<IFSEntityAbstract>().Now(), null) { }
    public DirectoryInfo? DirectoryInfo { get; set; }
  }


  public class FSEntityFile : FSEntityAbstract, IFSEntityFile
  {

    public FileInfo? FileInfo { get; set; }

    public string? Hash { get; set; }

    public FSEntityFile(string path, FileInfo? fileInfo, string? hash, IPhilote<IFSEntityAbstract> philote, Exception? exception) : base(path, philote, exception)
    {
      FileInfo = fileInfo;
      Hash = hash;
    }
    public FSEntityFile() : this("", null, null, new Philote.Philote<IFSEntityAbstract>().Now(), null) { }
    public FSEntityFile(string path) : this(path, null, null, new Philote.Philote<IFSEntityAbstract>().Now(), null) { }
    //public FSEntityFile(string path, IPhilote<IFSEntityFile> philote) : this(path, philote, new List<Exception>()) { }
    //public FSEntityFile(string path, IPhilote<IFSEntityFile> philote, IList<Exception> exceptions) : this(path, null,null, philote , exceptions) { }
    //public FSEntityFile(FileInfo? fileInfo, string? hash) :base()
    //{
    //  FileInfo = fileInfo;
    //  Hash = hash;
    //}
    //public FSEntityFile(string path, FileInfo? fileInfo, string? hash) : base(path)
    //{
    //  FileInfo = fileInfo;
    //  Hash = hash;
    //}

  }


  public class FSEntityArchiveFile : FSEntityAbstract
  {
  }

  public class FSEntitySoftLink : FSEntityAbstract
  {
  }

  public class FSEntityHardLink : FSEntityAbstract
  {
  }
}
