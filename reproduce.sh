#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
baseline_dir=$(mktemp -d "${TMPDIR:-/tmp}/pnpm-peer-11271-XXXXXX")
current_dir=$(mktemp -d "${TMPDIR:-/tmp}/pnpm-peer-11285-XXXXXX")
export CI=true

prepare_fixture() {
    local target_dir=$1
    local pnpm_version=$2
    cp -R "$source_dir/package.json" "$source_dir/pnpm-workspace.yaml" "$source_dir/pnpm-lock.yaml" \
        "$source_dir/packages" "$source_dir/registry" "$source_dir/scripts" "$target_dir/"
    node - "$target_dir/package.json" "$pnpm_version" <<'NODE'
const fs = require('node:fs');
const [file, version] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(file, 'utf8'));
pkg.packageManager = `pnpm@${version}`;
fs.writeFileSync(file, `${JSON.stringify(pkg, null, 2)}\n`);
NODE
}

prepare_fixture "$baseline_dir" 11.27.1
printf '\n=== Fresh install with pnpm 11.27.1 ===\n'
(
    cd "$baseline_dir"
    pnpm --version
    pnpm install --frozen-lockfile
    pnpm dedupe
    cmp "$source_dir/pnpm-lock.yaml" pnpm-lock.yaml
    test -L packages/consumer/node_modules/ms
    node scripts/check-resolution.cjs
)

prepare_fixture "$current_dir" 11.28.5
printf '\n=== Fresh install with pnpm 11.28.5 ===\n'
(
    cd "$current_dir"
    pnpm --version
    pnpm install --frozen-lockfile
    test -L packages/consumer/node_modules/ms
    node scripts/check-resolution.cjs
    pnpm dedupe
    cmp "$source_dir/pnpm-lock.yaml" pnpm-lock.yaml
    test -L packages/consumer/node_modules/ms
    if node scripts/check-resolution.cjs; then
        echo 'Unexpected: the hoisted package still resolves after dedupe.' >&2
        exit 1
    fi
)

printf '\nReproduced missing hoisted link in %s\n' "$current_dir"
