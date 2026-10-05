import { createApp } from 'vue'
import App from './App.vue'
import router from './router'

// Mount through the router so its auth/session guard runs before the first view.
createApp(App)
  .use(router)
  .mount('#app')