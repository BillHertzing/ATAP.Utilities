using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  public static class FSEntityExtensions
  {
    //Projection for FD, FF, and FA use the DirectoryInfo.FullName, FileInfo.FullName, and / or Path properties 
    public static string GetFullName(this IFSEntityAbstract fSEntityAbstract)
    {
      Func<FSEntityDirectory, string> PFD = new Func<FSEntityDirectory, string>((fSEntityDirectory) => {
        return fSEntityDirectory.DirectoryInfo != null ? fSEntityDirectory.DirectoryInfo.FullName : fSEntityDirectory.Path.Replace('/','\\');
      }) ;
      Func<FSEntityFile, string> PFF = new Func<FSEntityFile, string>((fSEntityFile) => {
        return fSEntityFile.FileInfo != null ? fSEntityFile.FileInfo.FullName : fSEntityFile.Path.Replace('/', '\\');
      });
      Func<FSEntityArchiveFile, string> PFA = new Func<FSEntityArchiveFile, string>((fSEntityArchiveFile) => {
        return fSEntityArchiveFile.FileInfo != null ?  fSEntityArchiveFile.FileInfo.FullName : fSEntityArchiveFile.Path.Replace('/', '\\');
      });

      switch (fSEntityAbstract)
      {
        case FSEntityDirectory directory:
        {
          return PFD(fSEntityAbstract as FSEntityDirectory);
        }
        case FSEntityArchiveFile file: // Important to handle the more-derived type (subclass) before handling a less-derived type (superclass) 
        {
          return PFA(fSEntityAbstract as FSEntityArchiveFile);
        }
        case FSEntityFile file:
        {
          return PFF(fSEntityAbstract as FSEntityFile);
        }
        default:
        {
          throw new Exception(string.Format(CultureInfo.CurrentCulture, StringConstants.InvalidTypeInSwitchExceptionMessage, fSEntityAbstract));
        }
      }
    }

    //public static Tout GetObject<Tout>(this FSEntityAbstract fSEntityAbstract) where Tout : new()
    //{
    //  Tout ret = new Tout();
    //  return ret;
    //}
  }
}
