using System;
using System.IO;

namespace ATAP.Utilities.Testing
{
  public sealed class TemporaryFile : IDisposable
  {
    volatile bool disposed;
    readonly FileInfo file;
    public TemporaryFile() : this(Path.GetTempFileName()) { }
    public TemporaryFile(string fileName) : this(new FileInfo(fileName)) { }
    public TemporaryFile(FileInfo temporaryFile)
    {
      file = temporaryFile;
    }
    public TemporaryFile(Stream initialFileContents) : this()
    {
      using (var file = new FileStream(this, FileMode.Open))
      {
        initialFileContents.CopyTo(file);
      }
    }

    ~TemporaryFile()
    {
      if (!disposed)
      {
        Dispose();
      }
    }

    public static implicit operator FileInfo(TemporaryFile temporaryFile)
    {
      return temporaryFile.file;
    }
    public static implicit operator string(TemporaryFile temporaryFile)
    {
      return temporaryFile.file.FullName;
    }
    public static explicit operator TemporaryFile(FileInfo temporaryFile)
    {
      return new TemporaryFile(temporaryFile);
    }
    public void Dispose()
    {
      try
      {
        file.Delete();
        disposed = true;
      }
      catch (Exception) { } // Ignore
    }
    public FileInfo FileInfo { get { return file; } }



  }
  public static partial class Extensions
  {
    public static TemporaryFile CreateTemporaryFileEmpty(this TemporaryFile tf) {
      try
      {
        File.Delete(tf);
      }
      catch (Exception e) when (e is System.ArgumentNullException || e is System.Security.SecurityException || e is System.ArgumentException || e is System.UnauthorizedAccessException || e is System.IO.PathTooLongException || e is System.NotSupportedException)
      {
        throw new Exception("error deleting temporary file, details in innerException", e);

      }
      return tf;
    }
  }
}
