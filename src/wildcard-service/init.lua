local http_ng = require('resty.http_ng')
local cache_backend = require('resty.http_ng.backend.cache')
local resty_backend = require('resty.http_ng.backend.resty')
local resty_env = require('resty.env')
local cjson = require('cjson')

local _M = {
  _VERSION = '0.1'
}

local mt = {
  __index = _M
}

function _M.new(options)
  local opts = options or {}
  local backend = cache_backend.new(opts.client or resty_backend)

  local http_client = http_ng.new({
    backend = backend,
    options = { ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') or false } }
  })

  local api_host = assert(opts.api_host or getenv('API_HOST'), 'need API_HOST')
  local access_token = opts.access_token or getenv('ACCESS_TOKEN')

  return setmetatable({
    options = opts,
    http_client = http_client,
    api_host = api_host,
    access_token = access_token
  }, mt)
end

function _M:get_apicast_servers()
  local arg_host = _M.arg_host()
  local query = ngx.encode_args({ host = arg_host, access_token = self.access_token })

  if not arg_host then
    ngx.log(ngx.WARN, 'missing host')
    return ngx.exit(404)
  end

  local enviroments = {'production', 'sandbox'}
  for i=1, #enviroments do
    local env = enviroments[i]
    local api_url = self.api_host .. '/admin/api/services/proxy/configs/' .. env .. '.json?' .. query
    local response = self.http_client.get(api_url)

    if response.status == 200 then
      configs = cjson.decode(response.body)
      if #configs.proxy_configs > 0 then
        local servers = {}
        for z = 1, #configs.proxy_configs do
          local proxy_config = configs.proxy_configs[z]
          local proxy = cjson.decode(proxy_config.content).proxy
          if env == 'production' then
            servers[#servers + 1] = proxy.endpoint
          else
            servers[#servers + 1] = proxy.sandbox_endpoint
          end
        end
        return servers
      end
    else
      ngx.print(response.body)
      return ngx.exit(response.status)
    end
  end

  return ngx.exit(404)
end

function _M.arg_host()
  local ngx_var = ngx.var or {}

  return ngx_var.arg_host
end

return _M
