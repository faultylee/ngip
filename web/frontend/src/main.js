import Vue from "vue";
import App from './App.vue'
import router from './router'
import $backend from './backend'

Vue.prototype.$backend = $backend
Vue.config.productionTip = false;

// ref: https://github.com/gtalarico/django-vue-template

const vue = new Vue({
  router,
  render: h => h(App)
})

vue.$mount('#app')
