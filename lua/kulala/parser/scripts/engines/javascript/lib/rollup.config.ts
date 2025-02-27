import typescript from '@rollup/plugin-typescript';
import { nodeResolve } from '@rollup/plugin-node-resolve';
import terser from '@rollup/plugin-terser';

export default [
  {
    input: './src/pre_request.ts',
    output: {
      dir: 'dist',
      format: 'cjs'
    },
    plugins: [
      typescript(),
      nodeResolve(),
      terser({
        mangle: {
          reserved: [
            'client',
            'request',
          ],
        },
      }),
    ],
  },
  {
    input: './src/post_request.ts',
    output: {
      dir: 'dist',
      format: 'cjs'
    },
    plugins: [
      typescript(),
      nodeResolve(),
      terser({
        mangle: {
          reserved: [
            'client',
            'response',
            'request',
            'assert'
          ],
        },
      }),
    ],
  },
]
