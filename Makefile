DOCKER_COMPOSE = docker-compose
S2I = s2i
REGISTRY ?= quay.io/3scale

IMAGE_NAME ?= wildcard-router-test
OPENRESTY_VERSION ?= 1.11.2.3-6
BUILDER_IMAGE ?= $(REGISTRY)/s2i-openresty-centos7:$(OPENRESTY_VERSION)
RUNTIME_IMAGE ?= $(BUILDER_IMAGE)-runtime

test: builder-image
	docker run $(BUILDER_IMAGE) /usr/libexec/s2i/run --daemon

build: rock
	$(S2I) build --rm . $(BUILDER_IMAGE) $(IMAGE_NAME)

builder-image: ## Build builder image
	$(S2I) build . $(BUILDER_IMAGE) $(IMAGE_NAME) --copy --incremental

runtime-image: PULL_POLICY ?= always
runtime-image: IMAGE_NAME = wildcard-router-test-runtime
runtime-image: ## Build runtime image
	$(S2I) build . $(BUILDER_IMAGE) $(IMAGE_NAME) --runtime-image=$(RUNTIME_IMAGE) --pull-policy=$(PULL_POLICY)


rock:
	luarocks make wildcard-service-scm-1.rockspec

prove: 
	TEST_NGINX_ERROR_LOG=/dev/stderr TEST_NGINX_BINARY=openresty prove
