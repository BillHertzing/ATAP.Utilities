import { LogLevel, ILogger } from '@Logger/Logger';


export class ExternalDataVetting {
  private message: string;

  constructor(private logger: ILogger) {
    this.message = 'starting ExternalDataVetting constructor';
    this.logger.log(this.message, LogLevel.Trace);
    this.message = 'leaving ExternalDataVetting constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }
}
