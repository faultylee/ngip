import Vue from "vue";
import App from "./App.vue";

Vue.config.productionTip = false;

//https://medium.freecodecamp.org/the-vue-handbook-a-thorough-introduction-to-vue-js-1e86835d8446
new Vue({
  render: h => h(App)
}).$mount("#app");
