test: build
	docker run --rm wildcard-service-app /usr/libexec/s2i/run --daemon

build: lock
	s2i build . quay.io/3scale/s2i-openresty-centos7:1.13.6.1-rover3 wildcard-service-app

lock:
	rover lock

prove: 
	TEST_NGINX_ERROR_LOG=/dev/stderr TEST_NGINX_BINARY=openresty prove

rover:
	rover install

run: rover
	rover exec openresty -g 'daemon off;' -c $(PWD)/nginx/main.conf
