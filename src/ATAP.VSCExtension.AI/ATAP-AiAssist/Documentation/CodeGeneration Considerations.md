tsconfig's outDir vs esbuild's outdir
https://stackoverflow.com/questions/73859007/tsconfigs-outdir-vs-esbuilds-outdir
09/26/2022

esbuild currently only inspects the following fields in tsconfig.json files:

alwaysStrict
baseUrl
extends
importsNotUsedAsValues
jsx
jsxFactory
jsxFragmentFactory
jsxImportSource
paths
preserveValueImports
target
useDefineForClassFields
Therefore you should use esbuild's outdir, the outDir configuration in tsfonfig.json will have no effect.
