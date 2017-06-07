local wildcard_service = require("wildcard-service")

describe('double-spec', function()

  it('exists', function()
    assert.truthy(wildcard_service)
  end)

  it('runs inside nginx', function ()
    assert.truthy(ngx)
  end)
end)
