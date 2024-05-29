## Orchestrating Actions in Visual Studio Code Extensions Using State Machines

Initial draft 2024-05-28, created from voice-to-text transcriptions of original author W.Hertzing, then summarized and organized by GPT-4o

State machines are powerful tools for managing complex workflows and ensuring that actions are performed in a controlled and predictable manner. In the context of Visual Studio Code extensions, state machines can be particularly useful for orchestrating various tasks and handling transitions between different states of the extension's lifecycle.

### Setting Up the Extension Hierarchy

In a Visual Studio Code extension, the hierarchy typically involves setting up observability, security, and data services. Once these foundational services are established, the primary state machine takes over to manage the core functionality of the extension.

#### The Role of the Primary State Machine

The primary state machine is responsible for orchestrating the main tasks the extension is designed to perform. Additionally, it must be prepared for disposal at any time to ensure proper resource management and cleanup. This includes handling the `deactivate` method, a required method for Visual Studio Code extensions.

### Handling Deactivation

The `deactivate` method is crucial for ensuring that the extension disposes of all subscriptions, stops asynchronous actions, stores its state, and cleans up resources and sensitive memory locations. Here’s how a typical `deactivate` method might look:
`typescriptexport function deactivate() {    if (primaryStateMachine) {        primaryStateMachine.dispose();    }    // Clean up other resources}`

### The Primary State Machine in Action

In the AI Assist extension, the primary state machine coordinates various tasks and calls two secondary state machines. One of these is the Quick Pick state machine, and the other is the Query Multiple Engine state machine.

### Naming Conventions for Context and Input Interfaces

Each state machine has context and input interfaces. The naming convention is to use a capital `I` prefix followed by `Context` or `Input`, the word `for`, and the name of the machine. The name of the machine is the value used in the `id` field in the definition of the machine as one of the properties of the parameter to the `createMachine` x-state function call.

#### Example Interfaces

```typescript interface IInputForPrimaryMachine {    // Define the input properties for the primary machine}
interface IContextForPrimaryMachine extends IInputForPrimaryMachine {    // Define the context properties for the primary machine}
interface IInputForQuickPickMachine {    // Define the input properties for the quick pick machine}
interface IContextForQuickPickMachine extends IInputForQuickPickMachine {    // Define the context properties for the quick pick machine}
interface IInputForQueryMultipleEngineMachine {    // Define the input properties for the query multiple engine machine}
interface IContextForQueryMultipleEngineMachine extends IInputForQueryMultipleEngineMachine {    // Define the context properties for the query multiple engine machine}
interface IInputForQuerySingleEngineMachine {    // Define the input properties for the query single engine machine}
interface IContextForQuerySingleEngineMachine extends IInputForQuerySingleEngineMachine {    // Define the context properties for the query single engine machine}
```

### Initializing State Machines

All state machine definitions begin by declaring the input of the state machine and then the context of the state machine. Every element of the input interface is included in the context, and the context values are initially set to the input values. This approach isolates information within the state machine's program hierarchical element, making the input irrelevant after it has been copied to the context.
If there are secure properties in the input, they can be erased or cleaned after they have been copied into the context. Subsequently, it is the context's responsibility to maintain security for this data.

#### Example of Secure Property Handling

```typescript
interface IInputForSecureMachine {    username: string;    password: string; // Secure property}
interface IContextForSecureMachine extends IInputForSecureMachine {    token: string;}
class SecureStateMachine {    private context: IContextForSecureMachine;
    constructor(input: IInputForSecureMachine) {        this.context = { ...input, token: '' };        // Clear sensitive input data        input.password = '';    }
    start() {        // Simulate authentication and token generation        this.context.token = 'secure_token';        console.log(`Authenticated as ${this.context.username}`);    }
    dispose() {        // Clean up sensitive data        this.context.token = '';    }}
```

### Quick Pick State Machine

The Quick Pick state machine is responsible for preparing the data necessary to display the Quick Pick dialog and receiving the user's response. When the primary state machine receives a Quick Pick start event, it triggers the Quick Pick state machine.
Here's a simplified example of how this might be implemented:

```typescript
class PrimaryStateMachine {    private quickPickStateMachine: QuickPickStateMachine;    private queryMultipleEngineStateMachine: QueryMultipleEngineStateMachine;
    constructor() {        this.quickPickStateMachine = new QuickPickStateMachine();        this.queryMultipleEngineStateMachine = new QueryMultipleEngineStateMachine();    }
    handleEvent(event: string) {        switch (event) {            case 'quickPickStart':                this.quickPickStateMachine.start();                break;            case 'queryMultipleEngineStart':                this.queryMultipleEngineStateMachine.start();                break;            // Handle other events        }    }
    dispose() {        this.quickPickStateMachine.dispose();        this.queryMultipleEngineStateMachine.dispose();        // Dispose of other resources    }}
class QuickPickStateMachine {    start() {        // Prepare data for Quick Pick        const items = ['Option 1', 'Option 2', 'Option 3'];        vscode.window.showQuickPick(items).then(selection => {            if (selection) {                console.log(`User selected: ${selection}`);            }        });    }
    dispose() {        // Clean up resources    }}
```

### Query Multiple Engine State Machine

The Query Multiple Engine state machine is the most complex part of the extension. It manages multiple query operations and must operate in parallel states: `operations` and `disposing`. This allows it to react appropriately to calls to the extension's `deactivate` method. The Query Multiple Engine state machine eventually calls one or more Query Single Engine machines.

```typescript
class QueryMultipleEngineStateMachine {    private querySingleEngines: QuerySingleEngineStateMachine[] = [];
    start() {        // Decide which enumerations to activate and spawn Query Single Engine machines        const enumerations = [EnumType1, EnumType2]; // Example enumerations        enumerations.forEach(enumeration => {            const engine = new QuerySingleEngineStateMachine({ enumeration });            this.querySingleEngines.push(engine);            engine.start();        });    }
    dispose() {        // Clean up resources and stop all query operations        this.querySingleEngines.forEach(engine => engine.dispose());    }
    getOutput() {        // Return a dictionary of Query Single Engine machine outputs keyed by enumeration        const output: { [key: string]: any } = {};        this.querySingleEngines.forEach(engine => {            output[engine.getContext().enumeration] = engine.getOutput();        });        return output;    }}
```

### Query Single Engine State Machine

The Query Single Engine state machine handles individual query operations and also operates in parallel states: `operations` and `disposing`. It can return various statuses, including errors, cancellations, or responses.

```typescript
class QuerySingleEngineStateMachine {    private context: IContextForQuerySingleEngineMachine;    private output: any;
    constructor(input: IInputForQuerySingleEngineMachine) {        this.context = { ...input };        this.output = null;    }
    start() {        // Simulate a query operation        this.output = this.queryService.send(this.context.enumeration);    }
    dispose() {        // Clean up resources for single query        console.log(`Disposing query operation for ${this.context.enumeration}`);    }
    getOutput() {        return this.output;    }
    getContext() {        return this.context;    }
    queryService = {        send: (enumeration: string) => {            // Simulate a query service sending a request based on enumeration            console.log(`Query sent for ${enumeration}`);            return `Response for ${enumeration}`;        }    }}
```

### Managing State Transitions

The primary machine receives its events from the VSC extensions CommandsService, or from the VSC extensions UI handling (clicks, etc).

Between the child machines in the hierarcy below the primary machine and from parent to child and back, the ATAP state machines follow the xstate models.

At the end of each invoked child (parallel) state machines the machine sends an activity done event. The nameing convention is <thenameoftheMachine>\_DONE.
each hild that implements the disposing state can also return the event <thenameoftheMachine>\_DONE

### Conclusion

Using state machines can handle the ordering of action sequences in response to stimuli (events) from outside the state machine. ATAP uses an opinionated semantics (verbose with long names) for defining the state machine. Each portion of a machine is assigned its own interface, and implementation of actual code is always delegated to actions. Most code execution happens in an entry action when a state is enetered.

---

Feel free to review and let me know if there are any additional details you'd like to include or any adjustments needed!

```

```
