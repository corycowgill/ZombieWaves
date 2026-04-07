import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@models': path.resolve(__dirname, 'src/models'),
      '@systems': path.resolve(__dirname, 'src/systems'),
      '@scenes': path.resolve(__dirname, 'src/scenes'),
      '@ui': path.resolve(__dirname, 'src/ui'),
      '@utils': path.resolve(__dirname, 'src/utils'),
    },
  },
  server: {
    host: '0.0.0.0',
    port: 3000,
  },
  build: {
    target: 'es2020',
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: true,
  },
});
