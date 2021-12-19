using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.StronglyTypedId;


namespace ATAP.Utilities.GenerateProgram {
  public static partial class GSolutionSignilExtensions<TValue> where TValue : notnull  {
    public static async Task<IGSolutionSignil<TValue>> FromStringAsync(string str, CancellationToken cancellationToken = default) {
      // parse out the Signil components from the string
      // EditorConfig
      // hasPropsAndTargets
      // hasArtifacts

      return new GSolutionSignil<TValue>();
    }

		// public static async Task<IGSolutionSignil<TValue>> FromFileAsync(FileInfo fh, CancellationToken cancellationToken = default)
		// {
			// //var workspace = MSBuildWorkspace.Create();
			// // ToDo: Add async error handling
			// //var solution = workspace.OpenSolutionAsync(fh.FullName).Result;
			// //solution.
			// GSolutionSignil<TValue> gSolutionSignil = new GSolutionSignil<TValue>();
			// return gSolutionSignil;
		// }

    //     public static async Task<IGSolutionSignil<TValue>> FromFileAsync(FileIO fh, CancellationToken cancellationToken = default) {
		// 	var workspace = MSBuildWorkspace.Create();
    //   // ToDo: Add async error handling
		// 	var solution = workspace.OpenSolutionAsync(fh.FullName).Result;
    //   solution.
    //   GSolutionSignil<TValue> gSolutionSignil = new GSolutionSignil<TValue>();
    //   return gSolutionSignil;
    // }

  }
}


