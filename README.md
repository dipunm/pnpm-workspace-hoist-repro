# pnpm `dedupe` hoisting reproduction

This standalone workspace reproduces a missing hoisted package link after upgrading from pnpm 11.27.1 to 11.28.2. It uses only a local workspace package and the public [`ms@2.1.3`](https://www.npmjs.com/package/ms/v/2.1.3) tarball downloaded from `https://registry.npmjs.org/ms/-/ms-2.1.3.tgz`. No private registry or service is needed.

This was extracted from the lint failure in [opentable/otjs-libraries#2822](https://github.com/opentable/otjs-libraries/pull/2822). There, `otjs-metrics` links to the local `otjs-logger` workspace package, while another dependency resolves a published `otjs-logger` copy. `eslint-plugin-jest` checks mocked module paths with `require.resolve()` from its own location inside pnpm's virtual store. The missing hoisted link makes that check report `otjs-logger` as missing even though the workspace link exists. This fixture substitutes a public tarball for the published logger copy; it reproduces the resolution behavior without reproducing the private dependency chain.

## Run

```sh
./reproduce.sh
```

The script creates an isolated directory under the system temporary directory and prints its path at the end. It verifies that code running from pnpm's virtual store can resolve `ms` after pnpm 11.27.1 `dedupe`, then upgrades only `packageManager` to 11.28.2, runs a frozen install and `dedupe`, and checks resolution again. The expected final output includes `MODULE_NOT_FOUND`; the script exits successfully only when the failure is reproduced.

The root `package.json` remains pinned to 11.27.1 so the script can be rerun. A launcher that honors the `packageManager` field must have access to both pnpm versions.

The script uses `--offline`. The `ms` tarball is included, but the pnpm versions must already be available locally. If needed, run `pnpm --version` once with each `packageManager` version to let your launcher fetch them before running the script.

## Why this shape matters

`packages/ms` is a workspace project named `ms`. `packages/consumer` uses that workspace project. `packages/registry-user` uses the published `ms@2.1.3` tarball through a `file:` dependency. `scripts/check-resolution.cjs` resolves `ms` from a path inside pnpm's virtual store, as an installed tool such as an ESLint plugin would.

After pnpm 11.27.1 `dedupe`, `node_modules/.pnpm/node_modules/ms` points to the tarball copy. After the 11.28.2 frozen install it points to the workspace copy. After 11.28.2 `dedupe`, the link is gone and the resolution check fails, while the lockfile remains valid.

## Workspace-only control

```sh
./scripts/reproduce-workspace-only.sh
```

This variant contains only `packages/ms` and `packages/consumer`. The consumer's `workspace:*` dependency links directly to `packages/ms` in both pnpm versions. It does **not** reproduce the regression: code running from the virtual store cannot resolve `ms` after 11.27.1 `dedupe`, but can resolve it after 11.28.2 `dedupe`. The main reproduction requires the second copy of `ms` supplied through the public tarball `file:` dependency.
