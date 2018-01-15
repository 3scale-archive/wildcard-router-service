use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
my $nginx = $ENV{TEST_NGINX_ROOT_PATH} || "$pwd";

$ENV{TEST_NGINX_LUA_PATH} = "$nginx/src/?.lua;$nginx/src/?/init.lua;;";
$ENV{TEST_NGINX_UPSTREAM_CONFIG} = "$nginx/conf/upstream_wildcard.conf";
$ENV{TEST_NGINX_DEFAULT_CONFIG} = "$nginx/conf/default_wildcard.conf";
$ENV{TEST_NGINX_SERVICE_CONFIG} = "$nginx/conf/service_wildcard.conf";

log_level('debug');
repeat_each(2);
no_root_location();
run_tests();

env_to_nginx(
  'RESOLVER',
  'API_HOST',
  'ACCESS_TOKEN',
  'APICAST_PORT',
  'APICAST_STAGING_ENDPOINT'
);

__DATA__

=== TEST 1: request though the wildcard router

--- http_config
  include $TEST_NGINX_UPSTREAM_CONFIG;
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('resty.resolver.cache').shared():save({
      { name = 'apicast-staging.', address = '127.0.0.1' },
      { name = 'foo-apicast-staging.example.com.', address = '127.0.0.1' },
    })
  }

  server {
    listen $TEST_NGINX_SERVER_PORT;
    server_name foo-apicast-staging.example.com;
    location / {
      content_by_lua_block {
        ngx.status = 200;
      }
    }
  }
--- config
  include $TEST_NGINX_DEFAULT_CONFIG;
--- request
GET /
--- more_headers
Host: foo-apicast-staging.example.com
--- response_body chomp
--- error_code: 200


=== TEST 2: request though the wildcard router using the API

--- main_config
env API_HOST=http://alaska-token@api.example.com:$TEST_NGINX_SERVER_PORT;
env APICAST_STAGING_SERVICE_PORT=1950;
env APICAST_STAGING_SERVICE=test-apicast-staging;
--- http_config
  lua_package_path "$TEST_NGINX_LUA_PATH";
  init_by_lua_block {
    require('resty.resolver.cache').shared():save({
      { name = 'test-apicast-staging.', address = '127.0.0.1' },
      { name = 'api.example.com.', address = '127.0.0.1' },
    })
  }

  include $TEST_NGINX_UPSTREAM_CONFIG;
  server {
    listen 1950;
    server_name foo-apicast-staging.example.com;
    location / {
      content_by_lua_block {
        ngx.status = 200
      }
    }
  }
  server {
    listen $TEST_NGINX_SERVER_PORT;
    server_name api.example.com;
    location /master/api/domain/foo-apicast-staging.example.com {
        content_by_lua_block {
          local cjson = require('cjson')
          ngx.status = 200
          ngx.say(cjson.encode({
            apicast = { staging = true }
          }))
        }
    }
  }
--- config
  include $TEST_NGINX_SERVICE_CONFIG;
--- server_name chomp
foo-apicast-staging.example.com
--- request
GET /
--- more_headers
Host: foo-apicast-staging.example.com
--- error_code: 200
