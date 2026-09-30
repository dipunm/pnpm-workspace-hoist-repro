const { createRequire } = require('node:module');
const { join } = require('node:path');

// Mimics require.resolve() inside a tool installed in pnpm's virtual store.
const fromVirtualStore = createRequire(join(process.cwd(), 'node_modules/.pnpm/tool/node_modules/tool/index.js'));
try {
    console.log(fromVirtualStore.resolve('ms'));
} catch (error) {
    console.error(error.code, error.message);
    process.exitCode = 1;
}
