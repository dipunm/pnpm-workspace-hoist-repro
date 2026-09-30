#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repro_dir=$(mktemp -d "${TMPDIR:-/tmp}/pnpm-hoist-public-XXXXXX")
cp -R "$source_dir/package.json" "$source_dir/pnpm-workspace.yaml" "$source_dir/pnpm-lock.yaml" "$source_dir/packages" "$source_dir/registry" "$source_dir/scripts" "$repro_dir/"
cd "$repro_dir"
export CI=true

printf '\n=== pnpm 11.27.1 ===\n'
pnpm --version
pnpm install --frozen-lockfile --offline
pnpm dedupe --offline
node scripts/check-resolution.cjs

node -e "const fs=require('node:fs'); const file='package.json'; const pkg=JSON.parse(fs.readFileSync(file,'utf8')); pkg.packageManager='pnpm@11.28.2'; fs.writeFileSync(file, JSON.stringify(pkg, null, 2)+'\n')"

printf '\n=== pnpm 11.28.2 ===\n'
pnpm --version
pnpm install --frozen-lockfile --offline
pnpm dedupe --offline
if node scripts/check-resolution.cjs; then
    echo 'Unexpected: the hoisted package still resolves.' >&2
    exit 1
fi
printf '\nReproduced missing hoisted link in %s\n' "$repro_dir"
