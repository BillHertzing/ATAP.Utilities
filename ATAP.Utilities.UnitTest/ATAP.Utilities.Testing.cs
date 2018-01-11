using System;
using System.Diagnostics;
using System.IO;
using Newtonsoft.Json;
using System.Collections.Generic;
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

    // http://geekswithblogs.net/akraus1/archive/2013/12/28/154992.aspx
    interface ITempDir : IDisposable
    {
        string Name
        {
            get;
        }
    }


    class TempDir : ITempDir
    {
        public string Name
        {
            get;
            private set;
        }

        /// <summary>
        /// Create a temp directory named after your test in the %temp%\uTest\xxx directory
        /// which is deleted and all sub directories when the ITempDir object is disposed.
        /// </summary>
        /// <returns></returns>

        public static ITempDir Create()
        {
            var stack = new StackTrace(1);
            var sf = stack.GetFrame(0);
            return new TempDir(sf.GetMethod().Name);
        }

        public TempDir(string dirName)
        {
            if (String.IsNullOrEmpty(dirName))
            {
                throw new ArgumentException("dirName");
            }
            Name = Path.Combine(Path.GetTempPath(), "uTests", dirName);
            Directory.CreateDirectory(Name);
        }

        public void Dispose()
        {

            if (Name.Length < 10)
            {
                throw new InvalidOperationException(String.Format("Directory name seesm to be invalid. Do not delete recursively your hard disc.", Name));
            }

            // delete all files in temp directory
            foreach (var file in Directory.EnumerateFiles(Name, "*.*", SearchOption.AllDirectories))
            {
                File.Delete(file);
            }

            // and then the directory
            Directory.Delete(Name, true);
        }
    }
    #region Static Input Methods for Dealing with JSON formatted strings
    public static class InputMethodsForDealingWithJSONFormattedStrings
    {

        public static (string k1, string k2) DeSerializeSimpleTuple(string _input)
        {
            return JsonConvert.DeserializeObject<(string k1, string k2)>(_input);
        }

        public static string SerializeSimpleTuple((string k1, string k2) _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static (string k1, Dictionary<string, double> term1) DeSerializeDictionaryTuple(string _input)
        {
            return JsonConvert.DeserializeObject<(string k1, Dictionary<string, double> term1)>(_input);
        }

        public static string SerializeDictionaryTuple((string k1, Dictionary<string, double> term1) _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static string SerializeReadOnlyDictionaryTuple((string k1, IReadOnlyDictionary<string, double> term1) _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static (string k1, IReadOnlyDictionary<string, double> term1) DeSerializeReadOnlyDictionaryTuple(string _input)
        {
            return JsonConvert.DeserializeObject<(string k1, Dictionary<string, double> term1)>(_input);
        }
        public static string SerializeCollectionOfSimpleTuple(IEnumerable<(string k1, string k2)> _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static IEnumerable<(string k1, string k2)> DeSerializeSingleInputStringFormattedAsJSONCollectionOfSimpleTuples(string _input)
        {
            return JsonConvert.DeserializeObject<IEnumerable<(string k1, string k2)>>(_input);
        }
        public static string SerializeCollectionOfComplexTuple(IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)> _input)
        {
            return JsonConvert.SerializeObject(_input);
        }
        public static IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)> DeSerializeSingleInputStringFormattedAsJSONCollectionOfComplexTuples(string _input)
        {
            return JsonConvert.DeserializeObject<IEnumerable<(string k1, string k2, IReadOnlyDictionary<string, double> term1)>>(_input);
        }
    }
    #endregion  Static Input Methods for Dealing with JSON formatted strings
}
