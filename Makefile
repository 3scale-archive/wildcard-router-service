test: build
	docker run --rm wildcard-service-app /usr/libexec/s2i/run --daemon

build: rock
	s2i build . quay.io/3scale/s2i-openresty-centos7:1.11.2.3-5 wildcard-service-app

rock:
	luarocks make wildcard-service-scm-1.rockspec

prove: 
	TEST_NGINX_ERROR_LOG=/dev/stderr TEST_NGINX_BINARY=openresty prove
