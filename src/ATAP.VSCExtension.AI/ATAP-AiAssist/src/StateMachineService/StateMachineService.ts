import { ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import { logConstructor } from '@Decorators/index';

export interface IStateMachineService {
  getNextState(): string;
  getCurrentState(): string;
}

export class StateMachineService implements IStateMachineService {
  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
  ) {}

  getNextState(): string {
    return 'next state';
  }

  getCurrentState(): string {
    return 'current state';
  }
}
