# Atap Utility packages and code for a VoiceAttack Plugin

The package provides a numberof faacilites to create a VoiceAttack pluginbg, one dedicated to supporting the Age Of Empires (AOE) II game.

## Install rabbitMQ to provide a message queue for the plugin

[Installing on Windows](https://www.rabbitmq.com/install-windows.html)

choco install rabbitmq

This will also install the Erlang language server!
Assistant design

The APATAPAT Voiceattack plugin is intended to be an assistant for playing games. It offers these featires:

1) Coach mode: The plugin will provide verbal reminders of actions to  take

1) Automate tasks: The plugin will issue commands to the game to automate tasks, such as the commands needed to configure a ship for fighting, or landing.

1) the plugin will automate repetitive tasks that need to happen periodicity

To accomplish the Coach mode, Microsoft's Speech Synthesizer is used, and the plugin will 'say' pre-programmed phrases

To accomplish the task automation, the plugin will react to spoken commands (or hotkeys) by issuing keystrokes, mouse movements/button pressew, or joystick movement/button presses to the application window

To automate repetitive tasks, the plugin will perform a task automation, wait a period of time, then repeat. There are also provisions to repeat for fixed number of times, or indefinitely. The repetitive task automation can also be stopped at any time with a 'stop' command.

The plugin will keep a 'state of the game' , which tracks what the plugin thinks is happening in the game, such as Structures built, units created, technologies researched, etc. Or in another example, the kind of ship being flown, its armor and weapons, and carrying capacity, etc.

the plugin will keep a 'Build Order' list. The Build Order List is a list of game-actions, sorted by time, that are to be taken at some time in the future. This list can be modified by commands entered by the user.

actions from each of the three categories can also be triggered by changes in the 'state of the game'

examples:

For AOE IV
Prestart setup
Select civilization
Select Map
Select Water/NoWater

Unit Dictionary: Key is unit type, value is number Current each type of unit = Initial number based on civ
Structure Dictionary: Key is structure type, value is list of structures of that type
Technology Dictionary:

Structure includes Kind, Unit link, technology link, static current build time, static current resource cost, static current hit points, current health, current task,
Unit includes Kind, structure link, static current build time, static current resource cost, static current hit points, current health, current task, stance,
Technology includes Kind, structure link, static current build time, static current resource cost,
Start game

Prior to the start of the game, the current state is configured using the initial state values based on civ and map. The Build Order structure is also initialed according to the Build Order selected by the player

The command "Start Game"  is the first state change that begins to queue actions for the plugin to take.

In AOE, at the command `start game`, the plugin queues the command to create a villager in the Town Center structure.

`BuildVillagerInTownCenter(int TCCardinality, CancellationToken)` pseudocode:
This is an async task returning nothing, except for an error. Continue on any thread, create/use a cancellation token,

Get the TownCenter identified by TCCardinality from the Structures
Command - SelectTC(TCardinality)
if not busy :
    Set TownCenter busy
    #Command - SelectStructure(TC, TCCardinality); Command.execute
    #Command = CreateUnit(Villager); Command.execute
    Command - CreateUnitInStructure(Unit.Villager, Structure.TownCenter, TCCardinality); Command.Axecute
else :
    alert user that townCenter X cannot currently create a villager

`CreateVilligerLoopInNLimitM` pseudocode:
NumVillagersCreatedByLoop = 0
Get list of TownCenters from structures.
done if there are no TCs
NModified =
for index in 1..N
`BuildVillagerInTC(int TCCardinality)`

Each individual or repetitive command will be an async task. Each task will use the speech synthesizer or the stored VAProxy, and also a Reactive timer or interval to perform a delay. when the command has been issued and the delay expired, the task will return

Queueing up actions will take place over one or more message queues. The message queues will hold the commands to be issued

The architecture for game time decision and command issuance consists of these parts:
1) the set of inputs (variables, collections, and expressions) that define the state.
1) a set of outputs that enumerate the possible commands that can be issued
1) a set of rules that evaluate the state and supply the key(s) for the command(s) to be issued on the next clock tick
1) a system clock

## System Clock and Game Clock
The System Clock is not pausable. It runs from the time the plugin starts until it is stopped
The game clock is a gated duplicate of teh system clock. The gate turns the game clock on or off. The gate is controlled by the game-level variable "GameState" which can be one of the enumeration values of `PreInitialzed`, `Initialized`, `Running`, `Paused`, `Ended`.

## OutputCommand

A single OutputCommand controls one of the plugin output modules. Each output module can accept and process only the kinds of commands intended for that output module.

## Output Modules

1) Speech Synthesizer

1) VAProxy

1) (Future) 3rd party message queues, TCP, HTTP, persistence stores

### Speech Synthesizer

The Speech Synthesizer module accepts OutputCommands of the Enumeration `Say`, `Mute`, `UnMute`
The module has an Action that calls the ATAP Interface for Speech. The plugin loads a Shim that provides an implementation for that interface. Initially only a shim for the Microsoft Speech synthesizer is implemented.

#### Say

The `Say` OutputCommand has a property called Phrase that contains a text string.

## Possible Commands Collection

The collection of all possible commands is created at the lowermost level of the plugin. Each subsequent layer adds Commands to the collection. Individual Commands are accessed by a multi-part key. Each layer (group) of commands is identified by one part of the key.
Initially, the key is a text string, and the command collection is an immutable read-only Dictionary<string,ICommandAbstract>

### CommandKey

The CommandKey must be composable via a function that takes the current CommandKey as a prefix, and adds the layer identifier and the key for each Command in that layer


## CommandChaining

TBD

## State

On each rising edge of the `GameClock`, the `ActiveRuleSet` is evaluated agains the `State`. Rules with matching `SubState` have their `Commands` put into the `OperationsMessageQueue`. On each falling edge of the GameClock, the `ActiveRuleSet` is populated from the complete `State`.

## OperationsMessageQueues

There are two operationMessageQueues, one for normal priority commands, and one for high priority messages. Message Queues are emptied and the associated Commands are placed into async tasks and started. The task wait handles are placed into a `RunningTasks` structure.

## `OperationsMessageQueuesMonitors`

The `OperationsMessageQueuesMonitors` is a singleton task that subscribes to the RxObservable `OperationsMessageQueueMessageReceived` . When the
sequence produces an element, the task reads the message, validates it, creates a cancellationtoken, creates a task from the CommandKey in the message, starts the tasks, and places the task wait handle into the `RunningTasks` structure and the `cancellationToken` into the `RunningTasksCancellationGroups` keyed by the CancellationGroupKey from the message. If the command invokes an action in a structure, or is a Say action, block further processing

## RunningTasks Structure

Initially the runningTasks structure is implemented as a ConcurrentObservableDictionary<RunningTaskKey, Task>. The Dictionary implements an RxObservable for INotifyChanged events, including add, remove, and ??childelementchanged??

## RunningTasksMonitor

The `RunningTasksMonitor` is a singleton WaitAny task that monitors all of the task wait handles in the `RunningTasks` structure. The monitor simply removes the task wait handle of any task that successfully completes. The `RunningTasksMonitor` reports any tasks that completes with `IsFaulted`, and reports Exceptions and AggregateExceptions if any occur.  If the `RunningTasks` structure is empty, TaskMonitor sets up a callback to `StartTaskMonitor` on INotifyChaged:Add. The callback action for 'add' is cleared when a runningtask is inserted to prevent calling StartTaskMonitor when there is already a running task. RunningTaskMonitor has a method `CancelTasks(groupCancellationTokenKey)` which will look up a group of `RunningTaskKey` values from the `RunningTasksCancellationGroups` structure, and set the cancellation token to Cancelfor all of the RunningTasks identified inthe set of RunningTaskKeys.

## Kernel Monitor

The `KernelMonitor` is a singleton task that runs throughout the life of the plugin. The tasks subscribes to the RxObservable `SystemClock`. The `KernalMonitor` first task is to initialize the plugin runtime systems. It starts the `RunningTasksMonitor` and the `OperationsMessageQueuesMonitors`. It initializes the game data structures after each change entered by the user. It sets the `Initialized` state variable to `true`.

## Invoke1

The Invoke routine is how the Voiceattack core communicates with the plugin. Aby VA command that alls the plugin does so through the Invoke1 method.

## StartGame Command

The StartGame command comes in from the Invoke1, which puts the StartGame command key onto the operationsmessagequeue. The message queue raises the RxObservable, and its action takes the message, extracts the CommandKey, and `cancellationGroupKey` creates a cancellationtoken, puts the `cancellationtoken` into the`RunningTasksCancellationGroups` structure and the StartGame task wait handle into the `RunningTasks` structure, keyed by the RunningTaskKey (level:CommandEnumeration)

## StartGame Task

The Task get the initial set of commands from the build order structure, by getting those commands tagged with "set1". Issue all of them to the
issues the following commands to the operations message queue

1) Create villager in 1 (this deselects via esc, selects TC via h, Sets the busy flag for this structure, create villager via q, delays current unit build time (by setting up an observable timer), clears the structure's busy flag, adds one to numcurrentvillagers variable and creates a new villager kind of unit, puts the unit on the unit structure, assigns it a food task task ends successfully)

## Say Task

Grab a read lock on SSBusy. If SSBusy true, setup an IEventNotify on the state variable, the Action is the rest of this stuff starting with grab write lock, If false, grab write lock. Set state `SSBusy` to true, call SS with the phrase, create RxObservable for MinInterPhraseTime, Callback Action is to set state `SSBusy` to false, complete the task and return (IsFaulted = false)

1) say "six villagers on sheep, set TownCenter gather point to sheep".

1) Say "Set Scout to control group1, pick up closest sheep, bring to TownCenter 1"

1) Create villagers in 1 limit 9
 This command is the first that creates a command loop. this task does not complete until the limit has been reached. parse the TC index from the command. Grab a read lock on the TCBusy for that index, if busy, setup an INotifyEvent callback, if not, grab write lock and set to busy. Create Villager for that TC.



## CreateUnit Command
