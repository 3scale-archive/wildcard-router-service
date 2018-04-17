local wildcard_service = require('wildcard-service')
local test_backend_client = require('resty.http_ng.backend.test')
local resty_env = require('resty.env')
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

    it('caches calls to get domain info', function()
      local s = spy.on(test_backend, 'send')

      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        apicast = { staging = true }
      })}

      -- Make 2 calls, and check correct answer
      for _ = 1, 2 do assert.equal('apicast-staging', service:servers().query) end

      -- Assert the http client was called only once
      assert.spy(s).was_called(1)
    end)

    it('returns cached stale info and starts a light thread to refresh it', function()
      test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
      respond_with{ status = 200, body = cjson.encode({
        apicast = { staging = true }
      })}

      service.domain_cache:set(
        'sandbox.alaska.com',
        { apicast = { staging = true } },
        -1 -- Force stale info
      )

      assert.equal('apicast-staging', service:servers().query)

      -- Give some time to the timer to refresh the info
      ngx.sleep(1)

      -- Check that the timer refreshed the info
      local cached, stale = service.domain_cache:get('sandbox.alaska.com')
      assert.is_not_nil(cached)
      assert.is_nil(stale)
    end)

    it('allows to configure the cache TTL', function()
      -- With TTL = -1 items expire when they're stored
      resty_env.set('DOMAIN_CACHE_TTL', -1)

      -- Expect 2 calls
      for _ = 1, 2 do
        test_backend.expect{ url = 'https://alaska.com:8081/master/api/domain/sandbox.alaska.com' }.
        respond_with{ status = 200, body = cjson.encode({
          apicast = { staging = true }
        }) }
      end

      local wildcard = wildcard_service.new({
        client = test_backend,
        api_host = 'https://foo@alaska.com:8081',
      })

      local s = spy.on(test_backend, 'send')

      -- Make 2 calls, and check correct answer
      for _ = 1, 2 do assert.equal('apicast-staging', wildcard:servers().query) end

      -- Assert the http client was called twice. This means that setting
      -- DOMAIN_CACHE_TTL = -1 had effect.
      assert.spy(s).was_called(2)

      resty_env.reset()
    end)

  end)
end)
