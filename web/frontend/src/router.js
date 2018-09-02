import Vue from "vue";
import Router from "vue-router";
import Ping from "./components/Ping.vue";
import Token from "./components/Token.vue";

Vue.use(Router);

export default new Router({
  routes: [
    {
      path: "/",
      name: "ping",
      component: Ping
    },
    {
      path: "/ping/:pk",
      name: "token",
      component: Token
    }
  ]
});
