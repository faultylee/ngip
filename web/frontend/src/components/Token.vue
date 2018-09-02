<template>
  <div>
    <div class="app">
      <div>
        <h4 style="display: inline;"><router-link to="/">&#171;</router-link>  Tokens for Ping:
          <span style="font-style: italic">{{this.ping.name}}</span>
        </h4>
        <span style="padding-left: 10px;"><button id="add-new" @click="addToken()">Add New Token</button></span>
      </div>
      <table>
        <thead>
        <tr>
          <th>ID</th>
          <th>Token</th>
          <th>Last Received</th>
          <th>Action</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="(token, index) in tokens" :key="index">
          <td>{{token.pk}}</td>
          <td>{{token.token}}</td>
          <td>{{token.date_last_used}}</td>
          <td>
            <button id="show-modal" @click="editToken(token.pk, token.token)">Edit</button>
            <input type="submit" @click="deleteToken(token.pk, token.token)" value="Delete"/></td>
        </tr>
        </tbody>
      </table>
    </div>
    <div v-if="showEdit || showNew">
      <transition name="modal">
        <div class="modal-mask">
          <div class="modal-wrapper">
            <div class="modal-container">

              <div class="modal-header">
                <slot name="header" v-if="showEdit">
                  Edit: {{edit_token}}
                </slot>
                <slot name="header" v-if="showNew">
                  Add New Token
                </slot>
              </div>

              <div class="modal-body">
                <slot name="body">
                  <label>Token: </label> <input type="text" placeholder="Token Value" v-model="edit_token">
                </slot>
              </div>

              <div class="modal-footer">
                <slot name="footer">
                  <button class="modal-default-button" @click="saveNew(edit_token)" :disabled="!edit_token" v-if="showNew">Add</button>
                  <button class="modal-default-button" @click="saveEdit(edit_pk, edit_token)" :disabled="!edit_token" v-if="showEdit">Save</button>
                  <button class="modal-default-button" @click="showEdit = showNew = false">Cancel</button>
                </slot>
              </div>
            </div>
          </div>
        </div>
      </transition>
    </div>
  </div>
</template>

<script>
export default {
  name: "Token",
  data() {
    return {
      ping_pk: "",
      ping: "",
      showEdit: false,
      showNew: false,
      edit_pk: "",
      edit_token: "",
      tokens: []
    };
  },
  mounted() {
    this.ping_pk = this.$route.params.pk;
    this.fetchPingTokens(this.ping_pk);
  },
  methods: {
    addToken() {
      this.edit_pk = "";
      this.edit_token = "";
      this.showNew = true;
    },
    editToken(pk, token) {
      this.edit_pk = pk;
      this.edit_token = token;
      this.showEdit = true;
    },
    saveEdit(pk, token) {
      const payload = { token: token };
      this.$backend.$patchTokens(pk, payload).then(() => {
        this.fetchPingTokens(this.ping_pk);
        this.showEdit = false;
      });
    },
    saveNew(token) {
      //TODO: use default value in DRF instead of here
      const payload = {
        ping: this.ping_pk,
        token: token,
        status: "a",
        date_last_used: null
      };
      this.$backend.$postToken(payload).then(() => {
        this.fetchPingTokens(this.ping_pk);
        this.showNew = false;
      });
    },
    fetchPingTokens(ping_pk) {
      this.$backend.$fetchPings(ping_pk).then(responseData => {
        this.ping = responseData;
      });
      this.$backend.$fetchPingTokens(ping_pk).then(responseData => {
        this.tokens = responseData;
      });
    },
    deleteToken(pk, token) {
      if (confirm("Are you sure you want to delete " + token)) {
        this.$backend.$deleteTokens(pk).then(() => {
          this.tokens = this.tokens.filter(m => m.pk !== pk);
          this.fetchPingTokens(this.ping_pk);
        });
      }
    }
  }
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
hr {
  max-width: 65%;
}

.app {
  margin: 0 auto;
  max-width: 80%;
  text-align: left;
  padding: 1rem;
}

img {
  width: 250px;
  padding-top: 50px;
  padding-bottom: 50px;
}

body {
  font-family: Helvetica Neue, Arial, sans-serif;
  font-size: 14px;
  color: #444;
}

table {
  border: 2px solid #42b983;
  border-radius: 3px;
  background-color: #fff;
}

th {
  background-color: #42b983;
  color: rgba(255, 255, 255, 0.66);
  cursor: pointer;
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
}

td {
  background-color: #f9f9f9;
}

th,
td {
  min-width: 120px;
  padding: 10px 20px;
}

.modal-mask {
  position: fixed;
  z-index: 9998;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: table;
  transition: opacity 0.3s ease;
}

.modal-wrapper {
  display: table-cell;
  vertical-align: middle;
}

.modal-container {
  width: 300px;
  margin: 0px auto;
  padding: 20px 30px;
  background-color: #fff;
  border-radius: 2px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.33);
  transition: all 0.3s ease;
  font-family: Helvetica, Arial, sans-serif;
}

.modal-header h3 {
  margin-top: 0;
  color: #42b983;
}

.modal-body {
  margin: 20px 0;
}

.modal-default-button {
  float: right;
}

/*
   * The following styles are auto-applied to elements with
   * transition="modal" when their visibility is toggled
   * by Vue.js.
   *
   * You can easily play with the modal transition by editing
   * these styles.
   */

.modal-enter {
  opacity: 0;
}

.modal-leave-active {
  opacity: 0;
}

.modal-enter .modal-container,
.modal-leave-active .modal-container {
  -webkit-transform: scale(1.1);
  transform: scale(1.1);
}
</style>
