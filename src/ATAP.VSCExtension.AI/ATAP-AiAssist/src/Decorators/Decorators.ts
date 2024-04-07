import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';

/* After many hours, I've come to the conclusion that it is not possible to create a decorator for class methods,
   including getters and setters that can access a class' instance property (logger: ILogger)
   The reason is that the decorator is applied at compile time, and 'this' does not exist (it is a runtime thing)
   I could use a static logger on the Logger class, but would lose the 'scope' information from the logger instance

   ort interface IHasLogger {
  readonly logger: Logger;
}

// a factory method that creates a Typescript decorator that logs a synchronous class method entry and exit through the class' private logger: Logger property
export function logFunctionFactory(hasLogger: IHasLogger, level: LogLevel) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const originalMethod = descriptor.value; // Save a reference to the original method

    descriptor.value = function (...args: any[]) {
      // Now 'this' is correctly bound to the class instance
      // Ensure 'this.logger' is accessible and has a 'log' method
      if (hasLogger.logger && typeof hasLogger.logger.log === 'function') {
        hasLogger.logger.log(`${target.constructor.name} ${propertyKey} Starting`, level);
      }
      const start = level === LogLevel.Performance ? process.hrtime() : null;
      const result = originalMethod.apply(this, args); // Call the original method
      if (hasLogger.logger && typeof hasLogger.logger.log === 'function') {
        hasLogger.logger.log(`${target.constructor.name} ${propertyKey} Completed`, level);
      }
      // If Performance, calculate elapsed time
      if (level === LogLevel.Performance && start) {
        const [seconds, nanoseconds] = process.hrtime(start);
        const elapsed = (seconds * 1000 + nanoseconds / 1e6).toFixed(3);
        hasLogger.logger.log(`${target.constructor.name} ${propertyKey} Elapsed Time: ${elapsed}ms`, level);
      }
      return result; // Return the original method's return value
    };
  };
}
*/
export function logFunction(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method
  descriptor.value = function (...args: any[]) {
    console.log(`${target.constructor.name} ${propertyKey} Starting`);
    const result = originalMethod.apply(this, args); // Call the original method
    console.log(`${target.constructor.name} ${propertyKey} Completed`);
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

// A method decorator that logs the entry into an asynchronous method
export function logAsyncFunction(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method
  descriptor.value = async function (...args: any[]) {
    console.log(`${target.constructor.name} ${propertyKey} Starting`);
    const result = await originalMethod.apply(this, args); // Call the original method
    console.log(`${target.constructor.name} ${propertyKey} Completed`);
    // Logger.staticLog(`staticLogger: ${propertyKey} executed in ${finish - start} milliseconds`, LogLevel.Debug); // ToDo: theser is a bug in the staticLogger logic
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

// A method decorator that logs the execution time of the method
export function logExecutionTime(target: any, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor {
  const originalMethod = descriptor.value; // Save a reference to the original method

  descriptor.value = function (...args: any[]) {
    console.log(`${target.constructor.name} ${propertyKey} Starting`);
    const start = performance.now(); // Start timer
    const result = originalMethod.apply(this, args); // Call the original method
    const finish = performance.now(); // End timer
    console.log(`${target.constructor.name} ${propertyKey} Completed`);
    console.log(`${target.constructor.name} ${propertyKey} Executed in ${finish - start} milliseconds`);
    // Logger.staticLog(`staticLogger: ${propertyKey} executed in ${finish - start} milliseconds`, LogLevel.Debug); // ToDo: theser is a bug in the staticLogger logic
    return result; // Return the original method's return value
  };
  return descriptor; // Return the modified descriptor
}

export function logConstructorWithLogger(logger: ILogger) {
  return function <T extends new (...args: any[]) => {}>(originalConstructor: T) {
    return class extends originalConstructor {
      constructor(...args: any[]) {
        logger.log(`${originalConstructor.name}.ctor Starting`, LogLevel.Debug);
        super(...args);
        logger.log(`${originalConstructor.name}.ctor Completed`, LogLevel.Debug);
      }
    };
  };
}

export function logConstructor<T extends new (...args: any[]) => {}>(originalConstructor: T) {
  return class extends originalConstructor {
    constructor(...args: any[]) {
      // ToDo: replace console.log with a method from the logging class (static) or instance
      console.log(`${originalConstructor.name}.ctor Starting `, LogLevel.Debug);
      super(...args);
      console.log(`${originalConstructor.name}.ctor Completed`, LogLevel.Debug);
      //Logger.staticLog(`A new instance of ${originalConstructor.name} was created!`, LogLevel.Debug);
    }
  };
}
