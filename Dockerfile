FROM quay.io/3scale/apicast:master

ENV LUA_PATH="$HOME/src/?.lua;$HOME/src/?/init.lua;;"
ENV API_HOST \
    ACCESS_TOKEN \
    APICAST_PRODUCTION_ENDPOINT \
    APICAST_STAGING_ENDPOINT \
    APICAST_PORT

RUN mkdir -p wildcard-router/logs && ln -s /dev/stdout wildcard-router/logs/access.log && ln -s /dev/stderr wildcard-router/logs/error.log
COPY . wildcard-router

CMD ["/bin/bash", "-c", "openresty -p wildcard-router -c nginx/main.conf -g 'daemon off;'"]
