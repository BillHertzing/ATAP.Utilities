/* After many hours, I've come to the conclusion that it is not possible to create a decorator for class methods,
   including getters and setters that can access a class' instance property (logger: ILogger)
   The reason is that the decorator is applied  at compile time, and 'this' does not exist (it is a runtime thing)
*/

export {
  logConstructor,
  logMethod,
  logFunction,
  logAsyncFunction,
  logExecutionTime,
  /*
    IHasLogger,
  logFunctionFactory,
  */
} from "./Decorators";
