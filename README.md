# wildcard-service

Welcome to new project using [APIcast-cli](https://github.com/3scale/apicast-cli).

## Usage

You can start the server:

```shell
apicast-cli start -e development
```

## Deployment

Build process uses s2i to package docker image.

```shell
s2i build . quay.io/3scale/s2i-openresty-centos7:1.11.2.3-5  wildcard-service-app
```

You can deploy app to OpenShift by running:

```shell
oc new-app quay.io/3scale/s2i-openresty-centos7:1.11.2.3-5~https://github.com/[yourname]/wildcard-service.git
```

## Running the tests

```
luarocks install apicast-cli
apicast-cli busted
make prove
```

## Real testing

```
luarocks install apicast-cli
API_HOST=https://macejmic-admin.3scale.net ACCESS_TOKEN=abc apicast-cli start nginx/main.conf.liquid -v -e development
curl -H "Host: api-2445581374650.staging.gw.apicast.io" foobar-api.dev:1400
```
