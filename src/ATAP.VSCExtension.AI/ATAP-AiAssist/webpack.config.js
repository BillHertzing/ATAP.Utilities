import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
// use tsconfig paths
import { TsconfigPathsPlugin } from "tsconfig-paths-webpack-plugin";
export default {
  mode: "none", // this leaves the source code as close as possible to the original (when packaging we set this to 'production')
  entry: "./src/extension.ts", // the entry point of this extension, 📖 -> https://webpack.js.org/configuration/entry-context/
  target: "node", // VS Code extensions run in a Node.js-context 📖 -> https://webpack.js.org/configuration/node/
  output: {
    filename: "extension.js",
    // the bundle is stored in the '_generated/dist' folder (check package.json), 📖 -> https://webpack.js.org/configuration/output/
    path: resolve(dirname(fileURLToPath(import.meta.url)), "_generated/dist"),
    libraryTarget: "commonjs2",
  },
  externals: {
    // modules added here also need to be added in the .vscodeignore file
    vscode: "commonjs vscode", // the vscode-module is created on-the-fly and must be excluded. Add other modules that cannot be webpack'ed, 📖 -> https://webpack.js.org/configuration/externals/
    prettier: "commonjs prettier", // this line will exclude 'prettier' from the bundle. It has a transitive dependency which webpack cannot resolve
  },
  resolve: {
    // support reading TypeScript and JavaScript files, 📖 -> https://github.com/TypeStrong/ts-loader
    extensions: [".ts", ".tsx", ".js", ".jsx"],
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
        test: /\.ts$/,
        exclude: [/node_modules/],
        use: [
          {
            loader: "ts-loader",
            options: {
              // to speed up build times, we can use transpileOnly mode
              transpileOnly: true,
              // experimentalFileCaching: true,
              // cacheDirectory: resolve(dirname(fileURLToPath(import.meta.url)), ".cache"),
            },
          },
        ],
      },
      {
        test: /\.mjs$/,
        include: /node_modules/,
        type: "javascript/auto",
      },
    ],
  },
  devtool: "source-map",
  infrastructureLogging: {
    level: "log", // enables logging required for problem matchers
  },
};
