<template>
  <div>
    <div>
      <button id="add-new" @click="addPing()">Add New Ping</button>
    </div>
    <div class="app">
      <table>
        <thead>
        <tr>
          <th>ID</th>
          <th>Ping Name</th>
          <th>Last Received</th>
          <th>Token Count</th>
          <th>Action</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="(ping, index) in pings" :key="index">
          <td>{{ping.pk}}</td>
          <td>{{ping.name}}</td>
          <td>{{ping.date_last_received}}</td>
          <td><router-link :to="'/ping/' + ping.pk">{{ping.pingtokens.length}}</router-link></td>
          <td>
            <button id="show-modal" @click="editPing(ping.pk, ping.name)">Edit</button>
            <input type="submit" @click="deletePings(ping.pk, ping.name)" value="Delete"/></td>
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
                  Edit: {{edit_name}}
                </slot>
                <slot name="header" v-if="showNew">
                  Add New Ping
                </slot>
              </div>

              <div class="modal-body">
                <slot name="body">
                  <label>Name: </label> <input type="text" placeholder="Ping Name" v-model="edit_name">
                </slot>
              </div>

              <div class="modal-footer">
                <slot name="footer">
                  <button class="modal-default-button" @click="saveNew(edit_name)" :disabled="!edit_name" v-if="showNew">Add</button>
                  <button class="modal-default-button" @click="saveEdit(edit_pk, edit_name)" :disabled="!edit_name" v-if="showEdit">Save</button>
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
  name: "Ping",
  data() {
    return {
      showEdit: false,
      showNew: false,
      account_pk: "",
      edit_pk: "",
      edit_name: "",
      pings: []
    };
  },
  mounted() {
    this.fetchPings();
  },
  methods: {
    addPing() {
      this.edit_pk = "";
      this.edit_name = "";
      this.showNew = true;
    },
    editPing(pk, name) {
      this.edit_pk = pk;
      this.edit_name = name;
      this.showEdit = true;
    },
    saveEdit(pk, name) {
      const payload = { name: name };
      this.$backend.$patchPings(pk, payload).then(() => {
        this.fetchPings();
        this.showEdit = false;
      });
    },
    saveNew(name) {
      //TODO: use default value in DRF instead of here
      const payload = {
        name: name,
        status: "a",
        pingtokens: [],
        account: null
      };
      this.$backend.$postPings(payload).then(() => {
        this.fetchPings();
        this.showNew = false;
      });
    },
    fetchPings() {
      this.$backend.$fetchPings().then(responseData => {
        this.pings = responseData;
      });
    },
    deletePings(pk, name) {
      if (confirm("Are you sure you want to delete " + name)) {
        this.$backend.$deletePings(pk).then(() => {
          this.pings = this.pings.filter(m => m.pk !== pk);
          this.fetchPings();
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
