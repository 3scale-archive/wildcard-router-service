local http_ng = require('resty.http_ng')
local cache_backend = require('resty.http_ng.backend.cache')
local resty_backend = require('resty.http_ng.backend.resty')
local resty_env = require('resty.env')
local resty_resolver = require('resty.resolver')
local resty_url = require('resty.url')
local cjson = require('cjson')
local getenv = os.getenv
local unpack = unpack

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
  local apicast_production_endopoint = getenv('APICAST_PRODUCTION_ENDPOINT') or 'apicast-production'
  local apicast_staging_endpoint = getenv('APICAST_STAGING_ENDPOINT') or 'apicast-staging'
  local apicast_port = getenv('APICAST_PORT') or 8080

  return setmetatable({
    options = opts,
    http_client = http_client,
    api_host = api_host,
    access_token = access_token,
    apicast_production_endopoint = apicast_production_endopoint,
    apicast_staging_endpoint = apicast_staging_endpoint,
    apicast_port = apicast_port
  }, mt)
end

function _M:get_apicast_servers()
  local arg_host = _M.arg_host()
  local query = ngx.encode_args({ host = arg_host, access_token = self.access_token })

  if not arg_host then
    ngx.log(ngx.WARN, 'missing host')
    return ngx.exit(404)
  end

  local resolver = resty_resolver:instance()
  local enviroments = {'production', 'sandbox'}
  for i=1, #enviroments do
    local env = enviroments[i]
    local api_url = self.api_host .. '/admin/api/services/proxy/configs/' .. env .. '.json?' .. query
    local response = self.http_client.get(api_url)
    if response.status == 200 then
      local configs = cjson.decode(response.body)
      if #configs.proxy_configs > 0 then
        for z = 1, #configs.proxy_configs do
          local proxy_config = configs.proxy_configs[z].proxy_config
          local proxy = proxy_config.content.proxy
          local endpoint
            
          if env == 'production' then 
            local url = resty_url.split(proxy.endpoint)
            local _, _, _, host, _ = unpack(url)
            if arg_host == host then
              local resolver_servers = resolver:get_servers(self.apicast_production_endopoint, { port = self.apicast_port })
              ngx.log(ngx.INFO, 'servers for enviroment: ', env, ' found: ', resolver_servers)
              return resolver_servers
            end
          else
            local url = resty_url.split(proxy.sandbox_endpoint)
            local _, _, _, host, _ = unpack(url)
            if arg_host == host then
              local resolver_servers = resolver:get_servers(self.apicast_staging_endpoint, { port = self.apicast_port })
              ngx.log(ngx.INFO, 'servers for enviroment: ', env, ' found: ', resolver_servers)
              return resolver_servers
            end
          end
        end
      else
        ngx.log(ngx.WARN, 'no proxy configs for enviroment: ', env)
      end
    else
      ngx.print(response.body)
      ngx.log(ngx.WARN, 'API host ', self.api_host, ' not available')
      return {}
    end
  end

  return {}
end

function _M.arg_host()
  local ngx_var = ngx.var or {}

  return ngx_var.host
end

return _M
