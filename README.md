# pnpm `dedupe` removes a hoisted package installed for a peer dependency

This standalone workspace reproduces a missing hoisted package link with pnpm 11.28.5. It uses a workspace package named `ms`, a package that depends on it through `workspace:*`, and a packaged peer consumer that causes pnpm to install the public [`ms@2.1.3`](https://www.npmjs.com/package/ms/v/2.1.3) separately. No private registry or service is needed.

This models the lint failure in [opentable/otjs-libraries#2822](https://github.com/opentable/otjs-libraries/pull/2822). `otjs-server-logging` links to the local `otjs-logger` workspace package; `ot-discovery` has a peer dependency that resolves to a published `otjs-logger` copy. `eslint-plugin-jest` checks mocked module paths with `require.resolve()` from its own location inside pnpm's virtual store. When the hoisted link disappears, it reports the logger as missing even though the consuming package's workspace link exists.

## Run

```sh
./reproduce.sh
```

The script makes two separate temporary workspaces from the same lockfile, matching CI's fresh checkout. It installs and dedupes one with pnpm 11.27.1. It then installs the other with pnpm 11.28.5, verifies virtual-store resolution before `dedupe`, and checks it again afterward. The expected final output includes `MODULE_NOT_FOUND`; the script exits successfully only when the failure is reproduced.

The root `package.json` stays pinned to 11.27.1 so the script can be rerun. Your pnpm launcher must support the `packageManager` field and be able to run both versions. The first run needs network access to fetch the public `ms` package from npm.

## Why this shape matters

`packages/ms` is the workspace copy. `packages/consumer` depends on that copy through `workspace:*`. `registry/peer-user` declares a peer dependency on `ms@2.1.3`; its included tarball is a dependency of `packages/registry-user`. pnpm therefore resolves the second `ms` copy from npm as a **peer**, recorded under `peer-user` in `pnpm-lock.yaml`, rather than as a direct dependency of a workspace importer. `scripts/check-resolution.cjs` resolves `ms` from pnpm's virtual store, like the installed ESLint plugin.

After pnpm 11.27.1 `dedupe`, virtual-store resolution succeeds. With a fresh pnpm 11.28.5 install, it succeeds before `dedupe`; afterward, `node_modules/.pnpm/node_modules/ms` is gone and resolution fails. The direct `packages/consumer/node_modules/ms` workspace link remains present.

The earlier version of this fixture used a direct `file:` dependency on the published package. That case was fixed by [pnpm/pnpm#16491](https://github.com/pnpm/pnpm/pull/16491) and passes with pnpm 11.28.5. This version exercises the peer dependency case that remains in `otjs-libraries`.

## Workspace-only control

```sh
./scripts/reproduce-workspace-only.sh
```

This variant contains only `packages/ms` and `packages/consumer`. The consumer's `workspace:*` dependency links directly to `packages/ms` in both pnpm versions. It does **not** reproduce the regression: code running from the virtual store cannot resolve `ms` after 11.27.1 `dedupe`, but can resolve it after 11.28.5 `dedupe`. The main reproduction needs the separately resolved published copy introduced by the peer dependency.
