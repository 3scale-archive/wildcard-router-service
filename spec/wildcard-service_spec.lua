local wildcard_service = require('wildcard-service')
local test_backend_client = require('resty.http_ng.backend.test')
local cjson = require('cjson')

describe('wildcard router', function()

  local test_backend
  local service

  before_each(function()
    ngx.var = { host = 'sandbox.alaska.com' }

    test_backend = test_backend_client.new()
    service = wildcard_service.new({
      client = test_backend,
      api_host = 'https://foo@alaska.com:8081'
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

  describe(':servers', function()
    it('detects apicast-staging', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        apicast = { staging = true }
      })}

      assert.equal('apicast-staging', service:servers().query)
    end)

    it('detects apicast-production', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        apicast = { production = true }
      })}

      assert.equal('apicast-production', service:servers().query)
    end)

    it('detects system-master', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        master = true, developer = true
      })}

      assert.equal('system-master', service:servers().query)
    end)

    it('detects system-provider', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        provider = true
      })}

      assert.equal('system-provider', service:servers().query)
    end)

    it('detects system-developer', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        developer = true
      })}

      assert.equal('system-developer', service:servers().query)
    end)

  end)
end)
