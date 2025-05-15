using Microsoft.Win32.TaskScheduler;

using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface ITaskDefinition {
    string Description { get; }
    string Author { get; }
    IReadOnlyList<Trigger> Triggers { get; }
    IReadOnlyList<Action> Actions { get; }
    TaskSettings Settings { get; }
    TaskPrincipal Principal { get; }
    string XmlText { get; }
  }
  public interface ITaskDefinitions {
    IDictionary<string, ITaskDefinition> TaskDefinitions { get; }
  }
}
