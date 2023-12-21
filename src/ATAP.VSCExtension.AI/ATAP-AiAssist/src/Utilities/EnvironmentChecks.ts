import { match } from 'assert';
import { Logger, LogLevel } from '@Logger/index';

export function isRunningInDevelopmentEnvironment(): boolean {
  // Logger.staticLog('isRunningInDevelopmentEnvironment called', LogLevel.Debug);
  Logger.staticLog(
    `Environment matches development: ${process.env['Environment']?.toLowerCase() === 'development'}`,
    LogLevel.Debug,
  );
  Logger.staticLog(`process.env.VSCODE_DEV === '1': ${process.env.VSCODE_DEV === '1'}`, LogLevel.Debug);
  if (process.env['Environment']?.toLowerCase() === 'development' || process.env.VSCODE_DEV === '1') {
    process.env['Environment'] = 'development';
    return true;
  } else {
    return false;
  }
}

export function isRunningInTestingEnvironment(): boolean {
  if (process.env['Environment']?.toLowerCase().includes('test')) {
    return true;
  } else {
    return false;
  }
}
