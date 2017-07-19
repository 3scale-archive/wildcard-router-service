local wildcard_service = require('wildcard-service')
local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')

describe('double-spec', function()

  local test_backend
  local service

  before_each(function()
    ngx.var = { host = 'sandbox.alaska.com' }

    test_backend = test_backend_client.new()
    service = wildcard_service.new({
      client = test_backend,
      api_host = 'https://alaska.com:8081',
      access_token = 'abc'
    })
  end)

  it('exists', function()
    assert.truthy(wildcard_service)
  end)

  it('runs inside nginx', function ()
    assert.truthy(ngx)
  end)

  it(':new', function ()
    wildcard_service.new({ api_host = 'https://alaska.com:8081' })
  end)

  it(':get_apicast_servers', function()
    test_backend.expect{ url = 'https://alaska.com:8081/admin/api/services/proxy/configs/production.json?host=sandbox.alaska.com&access_token=abc' }.
      respond_with{ status = 200, body = cjson.encode({
        proxy_configs = {}
    })}
    test_backend.expect{ url = 'https://alaska.com:8081/admin/api/services/proxy/configs/sandbox.json?host=sandbox.alaska.com&access_token=abc' }.
      respond_with{ status = 200, body = cjson.encode({
        proxy_configs = {{ proxy_config = { content = { proxy = { endpoint = 'http://production.alaska.com', sandbox_endpoint = 'http://sandbox.alaska.com' }}} }}
    })}
    local servers_2 = service:get_apicast_servers()
    assert.equal('apicast-staging', servers_2.query)
  end)
end)
