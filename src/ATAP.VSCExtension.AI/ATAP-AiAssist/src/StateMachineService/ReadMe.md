# xState machines in the ATAP AiAssist Visual Studio Code (VSC) extension

This accompanies the source code for the StateMachineService feature/functional area. Its purpose is to

## Goals

We have manifold goals today! These include documenting to future me how the various features were developed and the tradeoffs; documenting some places where improvements can be made; Providing an example of xState design / code for something a bit complex;

ToDO: add a section on showing testing of xState machines

## Architecture

[architecture diagram](Insert ref to image server URL)

Top Down:
StateMachineService describes the types, input and output objects, events, and the asynchronous control logic [xState](TBD) for the features of the [AiAssist VSC extension](TBD).

Bottom Up:
one actor per each kind of asynchronous operation needed, e.g., fetching from an endpoint, writing files to disk, reading files from disk, applying VSC commands.

In the Middle:
The state machines get their "commands" from the VSC command palette. The user presses F1 in a VSC editor tab, and then 'aiassist-' and autocomplete will show all of the commands that the extension will respond to. Some of those commands interact with the primaryMachine via sending events to the instance of the ActorRef that was built from the primaryMachine definition.

Initialization:
The extension is initialized in the usual way for VSC extensions, in the `extension.ts` file. In the `extension.ts` file, space is reserved for the primaryMachine and all its ancillary support the by lines `let stateMachineService: IStateMachineService;` and later `stateMachineService.start();`

Top Down Again:
The interface defining the StateMachineService is very simple.

- `.start()` - method to start the service (mocks can be added here later for testing purposes)
- `.quickPick()` - method to interact with the VSC extension persistent storage
- `.sendQuery()` - method for sending a query and fetching a response from a limited set of API endpoints;
- `.dispose()` - method to dispose of any allocated resources in an actor or its descendents. This is implemented in all machines and classes (except the very simplest) for handling the situation when the VSC extension is deactivated.

```Typescript
export interface IStateMachineService {
  quickPick(data: IQuickPickEventPayload): void;
  sendQuery(data: IQueryEventPayload): void;
  start(): void;
  disposeAsync(): void;
}
```

xState States, Actions, and Transitions:

Root Actor System: The parent or root actor is the primaryMachine. It has an `operationsState` which starts in the initial `idleState`. `operationsState` currently has five parallel child states: `idleState`, `quickPickState`, `queryingState`, `updatingUIState`, and `errorState`.

`queryingState` spawns a child actor, having a definition that matches xStateMachine logic, named `queryMachine`.

`queryMachine` has two child states, `gatheringState` followed by `fetchingState`, then `waitingForAllState` and ending with `doneState`.

`gatheringstate` is an example of using fromPromise actor logic. it turns a collection of fragments into a string, and is asynchronous because it can open files and read them to get a fragment, if desired.

`fetchingState` is where the complicated stuff happens. It starts with an entry action that spawns 'some number' of child machines, and assigns them to a structure in the queryMachine's context. These child machines are instances of the `querySingleActorMachine`. In addition to the `entry:` action, the state defines just one transition, a transition to the `waitingForAllState`, that occurs on the `QUERY.SINGLE_ACTOR_DONE` event. This transition has one action, to assign to the `queryMachine`'s context the output of the `querySingleActorMachine`.

`waitingForAllState` is a simple gatekeeper. It does not allow the machine to progress to `doneState` until all of the `querySingleActorMachine` are done. The guard condition looks in the context at the dictionary of ActorRefs created when the child machines are spawned, with the dictionary of ActorOutputs that is updated each time a `querySingleActorMachine` completes. When the number of keys are equal, the `queryMachine` transitions to it's final `doneState`

`doneState` handles a few things. Since it a `final` state, its `status` (via queryMachineActorRef.getSnapshot() ) is set to 'done', and it's output is made ready for the parent machine to access. It also sends the

Meanwhile back at the `primaryMachine`...

The `primaryMachine` entered `queryingState` from the `idleState` on `QUERY.EVENT`. The `queryingState` spawned the `queryMachine`, and placed a reference to it into the `queryMachineActorRef` on the `primaryMachine`'s context. the `queryingState` then waits for the `QUERY.DONE` event.

When the `queryMachine` sends `QUERY.DONE` to it's parent, the `primaryMachine`, the `queryingState` transitions to `updatingUIState`, along with the action that stores the output of `queryMachine` into the `primaryMachine`'s context property `queryMachineOutput`.

The `updatingUIState` handles the visual changes to the VSC user interface. This VSC extension does not use a VSC webpage view, so UI changes are handeled almost exclusively within the editor tabs.

A few more constraints:
Every async operation the application undertakes should support resiliency, timeout and cancellation. Cancellation is accomplished via a CancellationTokenSource supplied by vscode. Every event sent to the primary machine that starts an async operation includes a cancellationToken. That cancellationToken, is passed along through each stage of the machine(s) and eventually is passed to the external (to any machine) async function. Timeout is accomplished via the resiliency library, which defines polices for timeout and retry for all async functions. Timeout is specified by having timeout values for the various external async functions stored in the vscode state data, therefore the timeout period is not passed as machine input or event payload

What all that means for the xState machines is that any actor logic, including PromiseLogic or MachineLogic, should accept a cTSToken argument on input, and return a type that includes isCancelled and isTimeout boolean properties.

Design considerations:
Design bias is towards longer descriptive object and method names. this facilitates reasoning about the design, ease of us for new developers exposed to the code base, and revisiting code after long periods away from it.

Code/File allocation is towards smaller file units being composed by functional area, rather than large single files containing multiplefunctional areas.

TypescriptLang.org playground URL(s)

- [primary machine and necessary types](https://www.typescriptlang.org/play?noImplicitThis=false&exactOptionalPropertyTypes=false&ts=5.5.0-dev.20240313#code/JYWwDg9gTgLgBAKjgQwM5wG6oMYQCYCmcAZlBCHAORa6GUDcAUKJLHAN5wAyEA5lwQwEANgBo4ASR69eBKHAC+JMhUoABabKgB6YADtCADwbNw0eJwkARZDGSLl5Kmpt2AynIzBsBXQYLGTCzmHHAAgtgw0ABKBMTiaKhyMACiQnowCaiowLx64nBJMACuYA6kTpSGqHYwBCaM2tooenAEesUgcrbAEK0QxHAwABZEANb6eOgDbR1dUD196CO2cNjIrQBGRACOxd5jYAcEeIwBrPDtnXAAivvYYwAKBylz3TC9reyMcHBNbahhPoYABaPDAVDITbCAggvQBUFA+FwNQwACeYAIOCgwDAoKxSJg2j0yBA+l4INwenSHz6PzgADUAMJuJnkEAbPAAWSuEjqIFe1wAvFRmaz2ZyeR0+QQBXNKKJ6Vz8AQpcUZXLhVRlYQ1RrBSAFfS7nI0WFZBk2SAOQY9fyDXARZQTVAzRaYFabdzefb5Yrfi60a9ePosXbZQ6nYHg6HUOHNYbFQozoYLkMMUQ7gdng8uchsMNQ1bIPCMgB5YiPHEc115gtFvp1QwwAAqjo49L22YOdcL8IiUSgsWIAH4AFzhSIxOIAHg2aISejRAD4mAomOcQujMbd7k8e-m+wQ3JjsMBiN42RkEW2Rd9fmBkFB2jAJwPp8Q50vFyumL8uw8OZjEyLZuC2EBjO046YDgKoAHRMhsPjCMIix6OBkF6H+cAAfuDwANKTBWBrvJ80FZoBLxvAstJYZ2e5ASkUBkFAPLZMgsjQTUOJ6Lw2G4UBiF6MhMJ4BOmwQBAMIbGuG6pluGa7t2uaHg217NreHa-MIfBaBOUi6XI2F4LYyD6a4yDYY+z4ZG+U5DrO84-qu9HKWMhEGMR1FoeRDFUZ0pF9PxfkPCBYEQVBE40PBQkiWhGHtMFblMSxbGQpxE7ceSSWUaFSEiKJ0ESVJBAyYw64pmm26ZiFYxpC+jzIGiOnIHgmn3jhtUeXgXkBTRnwThReF1d5tE5cNYUJXoUWwYQCH5Sh8URXRFWbmw1VKblYzvlA0jeBIehgMUrbtpocgWW2ABkm3DfVGSNc1ECtS2clVYpQ1ATte3YGWx1HSdd6uVt3W9fMaGDbVJH9UF9JHA8XBQiImUwDxfHlUw-wjDVbm9qGcB4BAWJwHoEDwM+JRQK085wBAf3HZVCk7h9B71vCv0wP97WrfJ63vcUpp3TAD0tW17YdXspoAGILLwXSWlJMKRANhQo+SADaAC6wWmpNy0zbQBDzcJBVLZhskM2wVwUNGvGhgAcqSWIOh1-xlpiehhMAlDoGEEj0v8BLAmCEJQjCcIIiCSJEKiGbYri+KAsCxKkuSlJ9DSnz0kywy2AA4o8mmUNnecF0avz-GEGTDGQcPe+Efu-EyqHFIQ7ZF83dD+n8zS55JvAwnXvv0gAQk+eBt6PUB4GX3dwAAGoPDdwLnZBjG3K8QUayZrZccy7gLtvwpLqG8Kgzv+80bvtJ7i8XwChLB5C0KwvCzaR3jMeYnHeIgoHGTJ2SXiadqQvkzo3HOMB86aQAIxwBnDOOAAAGLuFcq4128LfRuHciAilgfAuA0CUE9z7gPH2S9J7j1wXAhBAAmIh89MHL1Xu2PBCCADMSYLbwA2oGNw5IYRfT4N4dmnMxb0QPiGeEDsugQwkfbR2Z85ja1dLEVAJYkhcVVrxZRQZmLQDShxAgmjUY6NigVE44lJLSRWq9RmNVTQ7REcdVAmlYi4CnjOG2kiCDSKdnMcQvD+EEEESGH6dNWwuR3umJm-NXQ7WHC49sbjoB4E8bEoMh8fEKINOIeJjlvwtBXJEnm3C+amlxmzcJ7VxFxPsk4mAqBfIOLqeElxOiUr6KxOlIxyMTE1LRGYlCFi4DFWsebKJPD0kVIIMWPoL4KxVlAE+NE0yrxNgBlpTqpoPBQC8D4fSvDPDeAIDo6ZeTRx2UHMOL8C5CkuX-FM1SlSObHSabWJ5BB6kvXRlwuAwI5DEHzEQCQhzdnHM2UkAwgYwioDRMJAAFPSX46zwJuGKJsMkr4Vaoy7g8uRUjHayNdDGAlXRFGdFxWsUCU19YxQWqhWiU0u4AEoJxVnIBCAgM4MAQGAHgFyyZTBpk4AJFmR5ygqCoHBbQoqVKs3qEEMwbARWPPlRKyo0qJbvPlQ0CZikzpQAumLOAOkZByH0ga+g+NTLmVMooWxvMdyLJrCsj5aybynUMoa0yV1jS1VWeQEs8zKzVmWQG9SJ1Lp+vKW6wNczywhqWdqo87qNJMEaM0bAz5bBECxnAMAobk140IBePQwBaK-KpDUfNhbXVqpFEUUo8KOrVVQBOdgSg0CbN+FSdZbLa3hpRdhX4+h-r9qTXWlNjYbzDraDSNtSLfhwAAD6hGqhOZ0ABVCQTJ8KPB3fhAA+ikBkKQ7YtgYPmpqIsIbJRpMLJ6otkxLqXauzg66qA3G3bu-du7D1foPb+o9XIwhMgABISDtikQ9VgyxQcvY+R6rVb1bWmV8xQi7fhvuiQQDdX6UjRAAJrHtPeehD17H1EqDPeijz0MMvqw2ujMeHN0EeI-hojh6QPgcg9B2D8H6MMewx+ygVgJBuEeGWNw0GT1novQ4f4QkRlEHWEM8eqxqYfC6HBOALZRhwA5GqkAxRq0ow2DkWiQwIBDH0+CNREAkhuFqIbOzkAci8Sczm8QAB3UYz5CkoBQhAdYdRx7PlQLTKAPh0DeeAChZTygCAnDgphldTHMQbrExJqT0GmRli5I8LgKQWwpEoPa+kCgu75lom27tcBSgmTqNuzzdRXgozNErPoE54W9oRMyx0y46s9unc2OCvXRumq0HBU18KAAGDWc3Nec212ptFxCCBfDhv56AAAk7BxswDghtjIcFqoKFm+IaQAghDCDglYAgmxii8GZbOyri6FtNfE8tww5aBzKx6yNmA-WhSDY6i+g7Y3AfTa9dD3giKGNLvm2ARrBAls5o+6jr7OaUg-ZgH9voK2OtrbnZtjaEI4B7Yh8dw7Z2Lupd+Fdjbt37uPd4JS34L3F1vZfa5hz5IWsEEJ-j6acAAcRuB6D1LEOIeTbkLDubvP3O8AF0Lzr+QScZC2+TynUPqenYzOdy7fBrsiDuw9p7nOX3c6XYrmZgaYR1BVxkVb-2DsS6G2sKHMuYczfp3AWbtviwO+PMt53RPPjrZpFr3b+3dc0n15iQ3fvGc3bN6z9ncBLcMf+OBAmE5WrjwNlZwo7Rx55qy5J6TJG5PF+pmo5A3n4TjzOfZYchRrMrHgOWtYGxEtEGpsgILIWThwHC5F6LqWc8QCsBACc2BijMU24Zo85z0BPl2Kqlfre4gtHHvCqIM-+uyrGC3q5cRJ-NHAjP-PeBC8qmL7bmmgwB9D5zWFrE4+CBc67tb6r0Batg6dQ4wfITjH7TKUpaqTqhigGb6hg-5JjMpjbZp1DTLw6zzlyZongFRjh2ahxf4YFLr-DYBYEoRjjtB4H0iAFT7X5wBWAhzPyMishDAiCygEDtaLp8oboFoTrTIzzDYRrdacCjrHSKDu7Nqpay5QATjCGHaSEZ6NZmR-KHTHRwQKEZ5gEfLnITjFD+ClonDqHpI7J7K4ZKH-RwSQFGHHIGExrypaH1a6Ghh4DWFFrPJjr2ElqOGUoKDMqUoibWSD4wjCB8Eqw5oAGpYQCYjQx6AC7tp+456FjoA1A5pwA5wGAwjLD6Ycj6A0yRFoRP42ZEDL6hg6aSzABQDVozAwDebWb+FDLCAhF1CoB+76DlrACD4bp8owgC7BEvpJGNGxEI4vqdEh45oDGDEvpdYe7jEAY-oHrV7npjHjEI52BQCyBYqUDH7dEZ7jHW5LFLocbEayYLFTFLErFrEbqQH87OY9FLG7G3HbFLp3EI5yAsQxEnEvrUFlg3536txRAoAwD8h4jF7PhdDgjJF5ovHQDiCkx+axZJBDALB6AWafDF6lqD4dJQAC6742ZkDeYtBtB6JQB+4vqD7eZNRhF7EvpnFsEdF4BdHXEPFW6MmKDMmbHOaLFLGEDfy0RjjEkMYABEYQV6Nk8AfRRAsWIwawhYwg48YpGRGmQWeJ9gJmcgxeSQ-eJqEI8AMwyAGAyAcWeBswfUeRepwg-MqA4gcMa8cy4gGOBRbQzY7QOQfQouZmSJrRLp5a-Wfxea26Sh4Iw+48mwaI9p8IeJpp-MtpyO4J+mlA8+i+GQDIg+-MZWlR+mVsgU6unIBRrQ5MC+rQPp+mEgdJRAYpcE-JzJvwL4rovJlJhBzQ9eje9pGhaq2ZNQ0Aua+mz4xAcg7QPgSh9pB2fJJJ2QuQeg4hdZL6LZW+Z+xAghw5gxB2lZgxjZ+QC5zxNIy5COSQwg8Q65jxHJk5nuAhcAzqYasaEa3yR5vRj4je+eS4s6R51O95aIj5k5O5c5hSb5ex3hA27xSxiQyQgs8K1O4gW6gGcxRxF6We15s8Va8Ah63BLqg6CI7YB2KA6AZ5Lhdul535lJ8FcAh6f+DkgwDat545Gx-qHyCo-5exsKNQsoxZE4s205oYdOsFQxYk-urF8I7FHFI6yhWKzaJeu5ig7aIln55yNyzkohf5E5-FS6khc+UOch+54xChylEaqhpkW5Sx-w1kL4mUIge5ClS6x+IMxAUM4MGuh2iGIs5hXUREllo0EealgxAEgk1KesNlcEdlj6DlbkusmEul4xx+GJBisg2hDhTeIV7ltUgyokE4gKwgSQsVVuPhblvw3heFexeZlMhFxFw4OVgxTxtxGVP5iofJlxHm7JtF+MWIWa8cA0+5lAQpYpNmqwq5a+Wy2FcAvm3gwwsw6wYAqAxQDKRMxmwgHwYAMIDRRMxA0AKRnISIvAwpARIgPVwARMfxk101s10K7oqAcENxzxYetZk5-wq5zZsByIbZg4nZRA3ZvZxsA5eaQ5R5iQY58lR5kBp+H485-FS5mVhQ5FaVNlYNH5sVCgh5k5B246yFF5Q6wNq5L5xV4xz5X5yNxlqNblv5IOdVCOgFsAwFoFn6rGnGUFlAMF15BFiFA6iNqFIo6FXaWFUB8IqarYaNi5SwCFhVO+ZFDeFFv11F4ggBsF9F-ITF3FN1BAfF-FnB0tNhR4ctHFMhghElYloQH5lyH40ldysl+N31ClSlhFSF558qHNsOWgYNPONqpt9NFtUOahwNL6BltkElNtZlhhRy+y9tPBDNo2FhPtBAnteKro0sHEcsHoCsBAauE4euflrUDlUsMsUdbIQyauodPVAy9KwyyVqVLtXtOsXlmE8d8eideAydroQV7Qnt3hYN2VwNeVrQRF2+xAXNTJ+59dC5kxYtSxBx-65NxG3GEGUGMGcGKQMNex1J6xGOaOdQJ1AFautWn1eQRtP1Mt9S6t6FeNkuplRBERIZea4WY1DSoutMLyQOjgFAeawtaqhZKmgOhdtNd9M5H4aFUOr9oY5yGFk4s5et849yClB9egF4UAN9+mFhQSO022+Mcyhd54ouh6X9-YbdcEaxbgJII1wwpM8KiBfRJmcAAAhEKE6ATPCFTQTacdXBAHiWGXABifCpQPlrnCkbQz3gWQkUtWAO7COCOEQ0Q8vKTHYIUOipiviYYFiRCKNUQIgyMOThtvIJACNfVmAFTR3SVYXc3YRSg8Emgxg1g6gDgzAHg3BBff9L-YGGhlUho53fxbo3YToR4TFbjeVZOaVQjh448cyXPVjnUFPQxlyY1XiMrJQMgDw6VIiT4IvS+tWWiBur407u1sLkaAuQEOWgE8scxlQIk99r9mrjE94wudQbPoFvUXmnqTiLTNMHoHBHUzZU0XWaSeSROGrPuX3dPU+OcVQAAMRm3YVmO5G0QC5wTDFbFd3LkazMleOlWlW25vEdOzw0IGBrV1FzU6Z6bk7tXrBbC5qInIlzJl7WYVAUB17ObNFlofDtFUD6DVbABCDjPjFymZNKF3MPO1WLMTEi6fMMYV45bzEtgbqK5XE5qFNZXTPMnAs1WjF1VxNAsQhuYgutZh4pOVV1m937l-NV55YFZFYlYvPLFdM0lUCB725sEjEL26VeN2P3F8mkvgDB4LNpNnUksIsOZ24MvktJMu59CpN1kiZolBEQt+6zNeGUoYsI7-C5w6SbCD4InmYekFnWZQvK7nMI5YsyakaAu9P9Ns0uZsuObOaqEGtIv1BisVaKic5AA)
