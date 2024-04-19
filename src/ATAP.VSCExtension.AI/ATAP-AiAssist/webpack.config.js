// This is a ESM (ECMAScript Module) file, which means we can use the import and export keywords

import { dirname, resolve, join, relative } from "path";
import { fileURLToPath } from "url";
import fs from "fs";

//@ts-check
/** @typedef {import('webpack').Configuration} WebpackConfig **/

("use strict");
// use tsconfig paths
import { TsconfigPathsPlugin } from "tsconfig-paths-webpack-plugin";
// __dirname and __filename are legacy variables that are not available in ES6 modules
// we can use the fileURLToPath function to convert the import.meta.url to a file path
// and then use the path module to get the directory name
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function findTypeScriptFiles(directoryPath) {
  const discoveredFiles = []; // Array to store results
  const rootPath = directoryPath;
  const files = await fs.promises.readdir(directoryPath, { withFileTypes: true });
  for (const file of files) {
    const filePath = join(directoryPath, file.name).replace(/^src/, "./src").replace(/\.ts$/, "");

    if (file.isDirectory()) {
      // Recursively explore subdirectories
      const nestedFiles = await findTypeScriptFiles(filePath);
      discoveredFiles.push(...nestedFiles);
    } else if (file.name.endsWith(".ts") || file.name.endsWith(".mts")) {
      discoveredFiles.push(filePath);
    }
  }
  return discoveredFiles;
}

// When called from a VSC launch task, the env.Environment variable is set in the scripts section of the package.json file
const webpackConfigFunction = async (env) => {
  const environment = env.Environment.toLowerCase();
  const isDevelopment = environment === "development";
  const isProduction = environment === "production";
  const isTesting = environment.startsWith("testing");
  if (!isDevelopment && !isProduction && !isTesting) {
    throw new Error(`Invalid environment: ${env.Environment}`);
  }
  const files = await findTypeScriptFiles("./src");
  console.log("files", files);
  const getEnvironmentConfig = (env) => {
    const environment = env.Environment.toLowerCase();
    const basePath = resolve(__dirname, "_generated");
    // console.log("basePath", basePath);
    const config = {
      development: {
        outputPath: resolve(basePath, "development"),
        //entry: files,
        entry: "extension.ts",
        //filename: "extension.mts",
        filename: "[name].js", // [name] is a placeholder, it creates an output file for each entry name
        mode: "development",
        devtool: "source-map",
      },
      testing: {
        outputPath: resolve(basePath, "testing"),
        filename: "tests.bundle.js",
        mode: "development",
        devtool: "inline-source-map",
        entry: resolve(__dirname, "src/test/runTests.ts"),
      },
      production: {
        outputPath: resolve(basePath, "production"),
        filename: "bundle.js",
        mode: "production",
        devtool: false,
        entry: "./src/extension.mts",
      },
    };
    return config[environment];
  };
  const environmentSpecificConfig = await getEnvironmentConfig(env);
  console.log(
    `
  Environment: ${environment}
  mode: ${environmentSpecificConfig.mode}
  entry: ${environmentSpecificConfig.entry}
  devtool: ${environmentSpecificConfig.devtool}
  outputPath: ${environmentSpecificConfig.outputPath}
  filename: ${environmentSpecificConfig.filename}`,
  );
  // return a webpack configuration structure specific to the environment
  return {
    target: "node", // VS Code extensions run in a Node.js-context 📖 -> https://webpack.js.org/configuration/node/

    mode: environmentSpecificConfig.mode,
    entry: environmentSpecificConfig.entry,
    output: {
      path: environmentSpecificConfig.outputPath,
      filename: environmentSpecificConfig.filename,
    },
    devtool: environmentSpecificConfig.devtool,
    // modules that cannot be webpack'ed, 📖 -> https://webpack.js.org/configuration/externals/
    externals: {
      // modules added here also need to be added in the .vscodeignore file
      vscode: "commonjs vscode", // the vscode-module is created on-the-fly and must be excluded.
      prettier: "commonjs prettier", // this line will exclude 'prettier' from the bundle. It has a transitive dependency which webpack cannot resolve
    },
    resolve: {
      // support reading TypeScript and JavaScript files, 📖 -> https://github.com/TypeStrong/ts-loader
      extensions: [".ts", ".mts", ".tsx", ".js", ".jsx"],
      // Add the plugin to the list of plugins
      plugins: [
        new TsconfigPathsPlugin({
          /* options */
        }),
      ],
    },
    module: {
      rules: [
        {
          test: /\.[m]*ts$/,
          exclude: [/node_modules/],
          use: [
            {
              loader: "ts-loader",
              options: {
                // to speed up build times, we can use transpileOnly mode. Does no type checking
                transpileOnly: true,
                colors: true,
                // experimentalFileCaching: true,
                // cacheDirectory: resolve(dirname(fileURLToPath(import.meta.url)), ".cache"),
                // use an environment-specific directory for tsc's outDir
                //  override the outputDir specified in the tsconfig.json file
                compilerOptions: {
                  outDir: environmentSpecificConfig.outputPath,
                },
              },
            },
          ],
        },
        {
          test: /\.mjs$/,
          include: /node_modules/,
          type: "javascript/auto",
        },
        // need to better understand why we might need to load .js files with source-map-loader
        // {
        //   test: /\.js$/,
        //   use: "source-map-loader",
        //   enforce: "pre",
        // },
      ],
    },
    infrastructureLogging: {
      level: "log", // enables logging required for problem matchers
    },
  };
};
console.log("env.Environment", process.env.Environment);
const webpackConfigurationStructure = await webpackConfigFunction({ Environment: "development" });
console.log("webpackConfigurationStructure", JSON.stringify(webpackConfigurationStructure));
export default webpackConfigurationStructure;
// export default {
//   mode: "none", // this leaves the source code as close as possible to the original (when packaging we set this to 'production')
//   entry: "./src/extension.ts", // the entry point of this extension, 📖 -> https://webpack.js.org/configuration/entry-context/
//   target: "node", // VS Code extensions run in a Node.js-context 📖 -> https://webpack.js.org/configuration/node/
//   output: {
//     filename: "extension.js",
//     // the bundle is stored in the '_generated/dist' folder (check package.json), 📖 -> https://webpack.js.org/configuration/output/
//     path: resolve(__dirname, "_generated/dist"),
//     libraryTarget: "commonjs2",
//   },
//   externals: {
//     // modules added here also need to be added in the .vscodeignore file
//     vscode: "commonjs vscode", // the vscode-module is created on-the-fly and must be excluded. Add other modules that cannot be webpack'ed, 📖 -> https://webpack.js.org/configuration/externals/
//     prettier: "commonjs prettier", // this line will exclude 'prettier' from the bundle. It has a transitive dependency which webpack cannot resolve
//   },
//   resolve: {
//     // support reading TypeScript and JavaScript files, 📖 -> https://github.com/TypeStrong/ts-loader
//     extensions: [".ts", ".tsx", ".js", ".jsx"],
//     // Add the plugin to the list of plugins
//     plugins: [
//       new TsconfigPathsPlugin({
//         /* options */
//       }),
//     ],
//   },
//   module: {
//     rules: [
//       {
//         test: /\.ts$/,
//         exclude: [/node_modules/],
//         use: [
//           {
//             loader: "ts-loader",
//             options: {
//               // to speed up build times, we can use transpileOnly mode
//               transpileOnly: true,
//               // experimentalFileCaching: true,
//               // cacheDirectory: resolve(dirname(fileURLToPath(import.meta.url)), ".cache"),
//             },
//           },
//         ],
//       },
//       {
//         test: /\.mjs$/,
//         include: /node_modules/,
//         type: "javascript/auto",
//       },
//     ],
//   },
//   devtool: "source-map",
//   infrastructureLogging: {
//     level: "log", // enables logging required for problem matchers
//   },
// };
// Need to better understand what fallback is used for, and why it might be important for testing environment
// fallback: {
//   child_process: false, // Assuming you don't need a polyfill for this in tests
//   fs: false, // Assuming you don't need a polyfill for this in tests
//   os: require.resolve("os-browserify/browser"),
//   path: require.resolve("path-browserify"),
//   util: require.resolve("util/"),
//   net: false, // Assuming you don't need a polyfill for this in tests
//   tls: false, // Assuming you don't need a polyfill for this in tests
//   url: require.resolve("url/"),
//   assert: require.resolve("assert/"),
//   stream: require.resolve("stream-browserify"),
//   // ... other necessary fallbacks ...
// },
