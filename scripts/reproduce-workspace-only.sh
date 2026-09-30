#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repro_dir=$(mktemp -d "${TMPDIR:-/tmp}/pnpm-workspace-only-XXXXXX")
mkdir -p "$repro_dir/packages" "$repro_dir/scripts"
cp "$source_dir/package.json" "$source_dir/pnpm-workspace.yaml" "$repro_dir/"
cp -R "$source_dir/packages/ms" "$source_dir/packages/consumer" "$repro_dir/packages/"
cp "$source_dir/scripts/check-resolution.cjs" "$repro_dir/scripts/"
cd "$repro_dir"
export CI=true

printf '\n=== Workspace link with pnpm 11.27.1 ===\n'
pnpm --version
pnpm install --offline
pnpm dedupe --offline
printf 'consumer link: '
readlink packages/consumer/node_modules/ms
if node scripts/check-resolution.cjs; then
    echo 'Virtual-store resolution succeeds with 11.27.1.'
else
    echo 'Virtual-store resolution fails with 11.27.1.'
fi

node -e "const fs=require('node:fs'); const file='package.json'; const pkg=JSON.parse(fs.readFileSync(file,'utf8')); pkg.packageManager='pnpm@11.28.2'; fs.writeFileSync(file, JSON.stringify(pkg, null, 2)+'\n')"

printf '\n=== Workspace link with pnpm 11.28.2 ===\n'
pnpm --version
pnpm install --frozen-lockfile --offline
pnpm dedupe --offline
printf 'consumer link: '
readlink packages/consumer/node_modules/ms
if node scripts/check-resolution.cjs; then
    echo 'Workspace-only case still resolves after dedupe.'
else
    echo 'Workspace-only case fails after dedupe.'
fi
printf 'Test directory: %s\n' "$repro_dir"
