import { match } from "assert";

import { LogLevel, ILogger, Logger } from "@Logger/index";

export function isRunningInDevelopmentEnvironment(): boolean {
  if (
    process.env["Environment"]?.toLowerCase() === "development" ||
    process.env.VSCODE_DEV === "1"
  ) {
    process.env["Environment"] = "development";
    return true;
  } else {
    return false;
  }
}

export function isRunningInTestingEnvironment(): boolean {
  if (process.env["Environment"]?.toLowerCase().includes("test")) {
    return true;
  } else {
    return false;
  }
}
