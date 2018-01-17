BUILDER_IMAGE ?= quay.io/3scale/s2i-openresty-centos7:1.13.6.1-rover3

test: build
	docker run --rm --detach wildcard-service-app /usr/libexec/s2i/run

build: lock
	s2i build . $(BUILDER_IMAGE) wildcard-service-app

lock:
	rover lock

prove: 
	TEST_NGINX_ERROR_LOG=/dev/stderr TEST_NGINX_BINARY=openresty prove

rover:
	rover install

run: LOG_LEVEL ?= error
run: rover
	rover exec openresty -g 'daemon off; error_log stderr $(LOG_LEVEL);' -c $(PWD)/nginx/main.conf

dev:
	docker run --rm -it -v $(PWD):/opt/app-root/src $(BUILDER_IMAGE) rover exec bash
