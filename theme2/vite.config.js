import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Inject <script src="cordova.js"> into the mobile build only.
function injectCordovaScript(isCordova) {
  return {
    name: 'inject-cordova-js',
    transformIndexHtml: {
      order: 'post',
      handler(html) {
        if (!isCordova) return html
        return html.replace('</head>', '  <script src="cordova.js"></script>\n  </head>')
      },
    },
  }
}

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const isCordova = mode === 'cordova'

  return {
    plugins: [vue(), injectCordovaScript(isCordova)],

    base: isCordova ? './' : '/',
    build: isCordova ? { outDir: '../mobile/www', emptyOutDir: true, target: 'chrome69', cssTarget: 'chrome69' } : {},

    server: {
      proxy: {
        '/api': {
          target: process.env.VITE_API_PROXY_TARGET || process.env.API_PROXY_TARGET || 'http://localhost:4000',
          changeOrigin: true,
        },
      },
    },

    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
  }
})