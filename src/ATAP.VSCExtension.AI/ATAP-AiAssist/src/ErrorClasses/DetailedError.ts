

export class DetailedError extends Error {
  constructor(public message: string, public innerError?: Error) {
    super(message);
    // Set the prototype explicitly.
    Object.setPrototypeOf(this, DetailedError.prototype);

    // Capturing the stack trace keeps the error chain intact
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, DetailedError);
    }
    this.name = 'DetailedError';
    if (innerError) {
      this.message += `: ${innerError.message}`;
    }
  }
}
