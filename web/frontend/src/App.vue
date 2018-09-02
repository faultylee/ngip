<template>
  <div id="app">
    <h1>Welcome to ngip <span style="color: darkgrey">{{ env }}</span></h1>
    <router-view/>
  </div>
</template>
<script>
export default {
  data() {
    return {
      env:
        process.env.VUE_APP_ENVIRONMENT == "prod"
          ? ""
          : process.env.VUE_APP_ENVIRONMENT
    };
  }
};
</script>
<style>
#app {
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
