using System.Diagnostics;
using System.Diagnostics.Tracing;

namespace ATAP.Utilities.ETW {


    public sealed class ATAPUtilitiesETWProvider : EventSource {

        public static ATAPUtilitiesETWProvider Log = new ATAPUtilitiesETWProvider();

        public class Tasks {
            public const EventTask Information = (EventTask)1;
            public const EventTask MethodBoundry = (EventTask)2;
            public const EventTask MethodBoundryFromAspect = (EventTask)3;
        }

    [DebuggerStepThrough]
    [Event(1, Message = "{0}", Opcode = EventOpcode.Info, Task = Tasks.Information)]
        public void Information(string message,[System.Runtime.CompilerServices.CallerMemberName] string memberName = "") {
            if (IsEnabled()) {
                WriteEvent(1, message, memberName);
            }
        }
    [DebuggerStepThrough]
    [Event(2, Message = "{0}", Opcode = EventOpcode.Info, Task = Tasks.MethodBoundry)]
        public void MethodBoundry(string message, [System.Runtime.CompilerServices.CallerMemberName] string memberName = "") {
            if (IsEnabled()) {
                WriteEvent(2, message+memberName);
            }
        }
    [DebuggerStepThrough]
    [Event(3, Message = "{0}", Opcode = EventOpcode.Info, Task = Tasks.MethodBoundryFromAspect)]
        public void MethodBoundryFromAspect(string message) {
            if (IsEnabled()) {
                WriteEvent(3, message);
            }
        }
    }

}
