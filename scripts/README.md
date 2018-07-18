#Overview
This folder contains helper scripts to perform one time setup or to assist with CI jobs

## Note
- Some scripts expect the `../.env` file. Please refer to `../.env.example`
- For docker to work in Jenkins server, make sure to add the required user to `docker` group
  - `sudo usermod -a -G docker $USER`
 