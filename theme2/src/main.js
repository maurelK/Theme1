import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import './styles/global.css'

// Mount through the router so its auth/session guard runs before the first view.
function startApp() {
  createApp(App).use(router).mount('#app')
}

// In the Cordova app, wait until the native bridge is ready.
if (window.cordova) {
  document.addEventListener('deviceready', startApp, false)
} else {
  startApp()
}