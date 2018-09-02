import axios from "axios";

let $backend = axios.create({
  baseURL: process.env.VUE_APP_ROOT_API,
  timeout: 5000,
  headers: { "Content-Type": "application/json" }
});

// Response Interceptor to handle and log errors
$backend.interceptors.response.use(
  function(response) {
    return response;
  },
  function(error) {
    // eslint-disable-next-line
  console.log(error)
    return Promise.reject(error);
  }
);

$backend.$fetchPings = pk => {
  if (pk) {
    return $backend.get(`ping/` + pk + "/").then(response => response.data);
  } else {
    return $backend.get(`ping/`).then(response => response.data);
  }
};

$backend.$postPings = payload => {
  return $backend.post(`ping/`, payload).then(response => response.data);
};

$backend.$patchPings = (pk, payload) => {
  return $backend
    .patch(`ping/` + pk + "/", payload)
    .then(response => response.data);
};

$backend.$deletePings = pingId => {
  return $backend.delete(`ping/${pingId}`).then(response => response.data);
};

$backend.$fetchPingTokens = pk => {
  return $backend.get(`pingtokens/` + pk + "/").then(response => response.data);
};

$backend.$fetchTokens = pk => {
  return $backend.get(`token/` + pk + "/").then(response => response.data);
};

$backend.$postToken = payload => {
  return $backend.post(`token/`, payload).then(response => response.data);
};

$backend.$patchTokens = (pk, payload) => {
  return $backend
    .patch(`token/` + pk + "/", payload)
    .then(response => response.data);
};

$backend.$deleteTokens = tokenId => {
  return $backend.delete(`token/${tokenId}`).then(response => response.data);
};

export default $backend;
