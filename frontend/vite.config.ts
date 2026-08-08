import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'https://api-gateway-686574767001.europe-west1.run.app',
        changeOrigin: true,
        secure: true,
      },
    },
  },
})