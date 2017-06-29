local wildcard_service = require('wildcard-service')
local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')

describe('double-spec', function()

  local test_backend
  local service

  before_each(function()
    ngx.var = { arg_host = 'api-2.alaska.apicast.io' }

    test_backend = test_backend_client.new()
    service = wildcard_service.new({
      client = test_backend,
      api_host = 'https://alaska.com',
      access_token = 'abc'
    })
  end)

  it('exists', function()
    assert.truthy(wildcard_service)
  end)

  it('runs inside nginx', function ()
    assert.truthy(ngx)
  end)

  it(':get_apicast_servers', function()
    test_backend.expect{ url = 'https://alaska.com/admin/api/services/proxy/configs/production.json?host=api-2.alaska.apicast.io&access_token=abc' }.
      respond_with{ status = 200, body = cjson.encode({
        proxy_configs = {}
    })}
    test_backend.expect{ url = 'https://alaska.com/admin/api/services/proxy/configs/sandbox.json?host=api-2.alaska.apicast.io&access_token=abc' }.
      respond_with{ status = 200, body = cjson.encode({
        proxy_configs = {{ content = cjson.encode({ proxy = { endpoint = 'http://production.alaska.com', sandbox_endpoint = 'http://sandbox.alaska.com' }}) }}
    })}
    local servers_2 = service:get_apicast_servers()
    assert.are.same({ 'http://sandbox.alaska.com' }, servers_2)
  end)
end)
