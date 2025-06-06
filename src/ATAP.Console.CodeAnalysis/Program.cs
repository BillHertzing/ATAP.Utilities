using Microsoft.Build.Locator;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Symbols;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.MSBuild;
using Microsoft.CodeAnalysis.Text;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.ConsoleCodeAnalysis
{
  class Program
  {
    static async Task Main(string[] args) {
      // Attempt to set the version of MSBuild.
      var visualStudioInstances = MSBuildLocator.QueryVisualStudioInstances().ToArray();
      var instance = visualStudioInstances.Length == 1
          // If there is only one instance of MSBuild on this machine, set that as the one to use.
          ? visualStudioInstances[0]
          // Handle selecting the version of MSBuild you want to use.
          : SelectVisualStudioInstance(visualStudioInstances);

      Console.WriteLine($"Using MSBuild at '{instance.MSBuildPath}' to load projects.");

      // NOTE: Be sure to register an instance with the MSBuildLocator
      //       before calling MSBuildWorkspace.Create()
      //       otherwise, MSBuildWorkspace won't MEF compose.
      MSBuildLocator.RegisterInstance(instance);

      using (var workspace = MSBuildWorkspace.Create()) {
        // Print message for WorkspaceFailed event to help diagnosing project load failures.
        workspace.WorkspaceFailed += (o, e) => Console.WriteLine(e.Diagnostic.Message);

        Console.WriteLine($"Loading solution '{args[0]}'");

        // Attach progress reporter so we print projects as they are loaded.
        // attribution: https://johnkoerner.com/csharp/creating-a-stand-alone-code-analyzer/
        Solution solution = workspace.OpenSolutionAsync(args[0], new ConsoleProgressReporter()).Result;
        Console.WriteLine($"Finished loading solution '{args[0]}'");

        // project name to analye
        string projectNameToAnalyze = "ATAP.Console.HelloWorld";
        //string projectNameToAnalyze = "ATAP.Utilities.GenerateProgram.Interfaces";
        Project projectToAnalyze;
        // get the GenerateProgram project
        if (solution.Projects.Any(q => q.Name == projectNameToAnalyze)) {
          projectToAnalyze = solution.Projects.First(p => p.Name == projectNameToAnalyze);
        }
        else {
          throw new ArgumentException($"{projectNameToAnalyze} does not exist in the solution");
        }
        //Compile it. wait for the compilation to complete and return
        Compilation compiledProject = projectToAnalyze.GetCompilationAsync().Result;
        // Task<Compilation?> compileProjectTask = projectToAnalyze.GetCompilationAsync();
        // compileProjectTask.Wait();
        // // ToDo: Exception Handling
        // Compilation? compiledProject = compileProjectTask.Result;

        // Get the classes inside the project
        foreach (var st in compiledProject.SyntaxTrees) {
          var sem = compiledProject.GetSemanticModel(st);
          //Find All Class Declartions
          var classDeclarations = st.GetRoot().DescendantNodes().OfType<ClassDeclarationSyntax>();
          foreach (ClassDeclarationSyntax classDeclaration in classDeclarations) {
            var classSymbol = sem.GetDeclaredSymbol(classDeclaration);
            Console.WriteLine($"Found class '{classSymbol.Name}'");

            //Name = classSymbol.Name
            //Namespace = classSymbol.ContainingNamespace
            //Location = classDeclaration.GetLocation().ToString()
          }
        }

        //foreach (var @class in compiledProject.GlobalNamespace.GetNamespaceMembers().SelectMany(x => x.GetMembers())) {
        //  Console.WriteLine(@class.Name);
        //  Console.WriteLine(@class.ContainingNamespace.Name);
        //}

      }
    }

    private static VisualStudioInstance SelectVisualStudioInstance(VisualStudioInstance[] visualStudioInstances)
    {
      Console.WriteLine("Multiple installs of MSBuild detected please select one:");
      for (int i = 0; i < visualStudioInstances.Length; i++)
      {
        Console.WriteLine($"Instance {i + 1}");
        Console.WriteLine($"    Name: {visualStudioInstances[i].Name}");
        Console.WriteLine($"    Version: {visualStudioInstances[i].Version}");
        Console.WriteLine($"    MSBuild Path: {visualStudioInstances[i].MSBuildPath}");
      }

      while (true)
      {
        var userResponse = Console.ReadLine();
        if (int.TryParse(userResponse, out int instanceNumber) &&
            instanceNumber > 0 &&
            instanceNumber <= visualStudioInstances.Length)
        {
          return visualStudioInstances[instanceNumber - 1];
        }
        Console.WriteLine("Input not accepted, try again.");
      }
    }

    private class ConsoleProgressReporter : IProgress<ProjectLoadProgress>
    {
      public void Report(ProjectLoadProgress loadProgress)
      {
        var projectDisplay = Path.GetFileName(loadProgress.FilePath);
        if (loadProgress.TargetFramework != null)
        {
          projectDisplay += $" ({loadProgress.TargetFramework})";
        }

        Console.WriteLine($"{loadProgress.Operation,-15} {loadProgress.ElapsedTime,-15:m\\:ss\\.fffffff} {projectDisplay}");
      }
    }
  }
}
