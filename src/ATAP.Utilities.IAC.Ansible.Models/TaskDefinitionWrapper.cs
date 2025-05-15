using Microsoft.Win32.TaskScheduler;

using System.Collections.Generic;

#pragma warning disable IDE0130 // Namespace does not match folder structure
namespace ATAP.Utilities.IAC.Ansible {
#pragma warning restore IDE0130 // Namespace does not match folder structure

  public record TaskDefinitionWrapper(
    string Description,
    string Author,
    IReadOnlyList<Trigger> Triggers,
    IReadOnlyList<Action> Actions,
    TaskSettings Settings,
    TaskPrincipal Principal,
    string XmlText) : ITaskDefinition {
    // Factory method to create a TaskDefinitionWrapper from TaskDefinition
    public static TaskDefinitionWrapper FromTaskDefinition(TaskDefinition taskDefinition) {
      var triggers = new List<Trigger>();
      foreach (var trigger in taskDefinition.Triggers) {
        triggers.Add(trigger);
      }

      var actions = new List<Action>();
      foreach (var action in taskDefinition.Actions) {
        actions.Add(action);
      }

      return new TaskDefinitionWrapper(
        Description: taskDefinition.RegistrationInfo.Description,
        Author: taskDefinition.RegistrationInfo.Author,
        Triggers: triggers.AsReadOnly(),
        Actions: actions.AsReadOnly(),
        Settings: taskDefinition.Settings,
        Principal: taskDefinition.Principal,
        XmlText: taskDefinition.XmlText
      );
    }
  }
}
