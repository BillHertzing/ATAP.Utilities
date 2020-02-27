using System;
using Medallion.Shell;
using System.Collections.Generic;
using ATAP.Utilities.ConcurrentObservableCollections;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;

namespace ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo
{

  public class ComputerProcess : IEquatable<ComputerProcess>, IComputerProcess
  {
    public ComputerProcess()
    {
    }

    public ComputerProcess(IComputerSoftwareProgram computerSoftwareProgram, Command command, object[] arguments )
    {
      Arguments = arguments ?? throw new ArgumentNullException(nameof(arguments));
      Command = command ?? throw new ArgumentNullException(nameof(command));
      ComputerSoftwareProgram = computerSoftwareProgram ?? throw new ArgumentNullException(nameof(computerSoftwareProgram));
    }

    public object[] Arguments { get; set; }
    public Command Command { get; set; }
    public IComputerSoftwareProgram ComputerSoftwareProgram { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerProcess);
    }

    public bool Equals(ComputerProcess other)
    {
      return other != null &&
             EqualityComparer<object[]>.Default.Equals(Arguments, other.Arguments) &&
             EqualityComparer<Command>.Default.Equals(Command, other.Command) &&
             EqualityComparer<IComputerSoftwareProgram>.Default.Equals(ComputerSoftwareProgram, other.ComputerSoftwareProgram);
    }


    public override int GetHashCode()
    {
      var hashCode = 1615262500;
      hashCode = hashCode * -1521134295 + EqualityComparer<object[]>.Default.GetHashCode(Arguments);
      hashCode = hashCode * -1521134295 + EqualityComparer<Command>.Default.GetHashCode(Command);
      hashCode = hashCode * -1521134295 + EqualityComparer<IComputerSoftwareProgram>.Default.GetHashCode(ComputerSoftwareProgram);
      return hashCode;
    }

    public IDisposable Subscribe(IObserver<IComputerProcess> observer)
    {
      throw new NotImplementedException();
    }

    public static bool operator ==(ComputerProcess left, ComputerProcess right)
    {
      return EqualityComparer<ComputerProcess>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerProcess left, ComputerProcess right)
    {
      return !(left == right);
    }
  }


  public class ComputerProcesses : IComputerProcesses, IEquatable<ComputerProcesses>
  {
    public ComputerProcesses()
    {
    }

    public ComputerProcesses(ConcurrentObservableDictionary<int, IComputerProcess> computerProcessDictionary)
    {
      ComputerProcessDictionary = computerProcessDictionary ?? throw new ArgumentNullException(nameof(computerProcessDictionary));
    }

    public ConcurrentObservableDictionary<int, IComputerProcess> ComputerProcessDictionary { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as ComputerProcesses);
    }

    public bool Equals(ComputerProcesses other)
    {
      return other != null &&
             EqualityComparer<ConcurrentObservableDictionary<int, IComputerProcess>>.Default.Equals(ComputerProcessDictionary, other.ComputerProcessDictionary);
    }

    public override int GetHashCode()
    {
      return 1598993677 + EqualityComparer<ConcurrentObservableDictionary<int, IComputerProcess>>.Default.GetHashCode(ComputerProcessDictionary);
    }

    public static bool operator ==(ComputerProcesses left, ComputerProcesses right)
    {
      return EqualityComparer<ComputerProcesses>.Default.Equals(left, right);
    }

    public static bool operator !=(ComputerProcesses left, ComputerProcesses right)
    {
      return !(left == right);
    }

    // The IObservable provider objects, classes, and methods
    // attribution:  https://docs.microsoft.com/en-us/dotnet/standard/events/how-to-implement-a-provider
    List<IObserver<IComputerProcesses>> Observers { get; }
    private class Unsubscriber : IDisposable
    {
      List<IObserver<IComputerProcesses>> Observers { get; }
      private IObserver<IComputerProcesses> Observer { get; }

      public Unsubscriber(List<IObserver<IComputerProcesses>> observers, IObserver<IComputerProcesses> observer)
      {
        Observers = observers ?? throw new ArgumentNullException(nameof(observers));
        Observer = observer ?? throw new ArgumentNullException(nameof(observer));
      }

      public void Dispose()
      {
        if (!(Observer == null))
        {
          Observers.Remove(Observer);
        }
      }
    }

    public IDisposable Subscribe(IObserver<IComputerProcesses> observer)
    {
      if (!Observers.Contains(observer))
      {
        Observers.Add(observer);
      }

      return new Unsubscriber(Observers, observer);
    }
    public void NotifyObservers()
    {
      //ToDo implement the method that gets a TempAndFan instance update
      throw new NotImplementedException();
      //foreach (var observer in observers)
      //  observer.OnNext(tempAndFanData); // An event should trigger this, and pass in a TempAndFan instance named tempAndFanData
      //}
      //foreach (var observer in observers.ToArray())
      //if (observer != null) observer.OnCompleted(); // this is the code to use if the instance will never send data again
      //}
      //observers.Clear();
    }


  }
}
