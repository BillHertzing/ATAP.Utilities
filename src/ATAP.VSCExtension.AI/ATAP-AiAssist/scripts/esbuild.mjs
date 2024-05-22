import * as esbuild from "esbuild";

const args = process.argv.slice(2);
const params = {};

const allowedParams = ["--env", "--outdir", "--outfile"];
const defaultParams = {
  env: "production",
  outdir: "_generated/production",
  outfile: "extension.js",
};
const allowedEnvs = ["production", "testing", "development"];

// Arguments must be either --key=value or --key, no whitespace allowed
args.forEach((arg) => {
  if (arg.indexOf("--") === -1) {
    // Invalid argument
    console.error(`Invalid argument: ${arg}`);
    process.exit(1);
  } else {
    if (arg.indexOf("=") === -1) {
      // There is no value, so it's a boolean flag
      params[arg.replace("--", "")] = true;
    } else {
      // There is a value, so it's a key-value pair
      const [key, value] = arg.split("=");
      params[key.replace("--", "")] = value;
    }
  }
});

// Check if all parameters are allowed
Object.keys(params).forEach((key) => {
  if (!allowedParams.includes(`--${key}`)) {
    console.error(`Invalid parameter: ${key}`);
    process.exit(1);
  }
});

// Set default values for missing parameters
Object.keys(defaultParams).forEach((key) => {
  if (!params[key]) {
    params[key] = defaultParams[key];
  }
});

// Check if the env parameter is valid
if (!allowedEnvs.includes(params.env)) {
  console.error(`Invalid environment: ${params.env}`);
  process.exit(1);
}

//  setup a structure for the esbuild options for each env value
const defaultEnvOptions = {
  production: {
    outdir: "_generated/production",
    outfile: "extension.js",
    sourcemap: true,
  },
  testing: {
    outdir: "_generated/testing",
    outfile: "extension.js",
    sourcemap: true,
  },
  development: {
    outdir: "_generated/development",
    outfile: "extension.js",
    sourcemap: false,
  },
};

// create a variable for the esbuild optionsthat are consta
const defaultESBuildOptions = {
  entryPoints: ["./src/extension.ts"],
  bundle: true,
  platform: "node",
  target: "node16",
};
const actualESBuildOptions = {
  ...defaultESBuildOptions,
  ...defaultEnvOptions[params.env],
  outdir: params.outdir,
  outfile: params.outfile,
  sourcemap: defaultEnvOptions[params.env].sourcemap,
};

await esbuild.build(actualESBuildOptions).catch((err) => {
  console.error(err);
  process.exit(1);
});
