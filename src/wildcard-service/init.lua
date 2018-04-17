local http_ng = require('resty.http_ng')
local cache_backend = require('resty.http_ng.backend.cache')
local resty_backend = require('resty.http_ng.backend.resty')
local resty_env = require('resty.env')
local resty_resolver = require('resty.resolver')
local resty_url = require('resty.url')
local lrucache = require('resty.lrucache')
local cjson = require('cjson')
local getenv = os.getenv
local gsub = string.gsub
local upper = string.upper
local setmetatable = setmetatable
local tonumber = tonumber

local _M = {
  _VERSION = '0.1'
}

local mt = {
  __index = _M
}

local function extract_service(name, default_port)
  local name_env = upper(gsub(name, '-', '_')) .. '_SERVICE'
  local port_env = name_env .. '_PORT'

  local service =  getenv(name_env) or name
  local port = getenv(port_env) or default_port

  ngx.log(ngx.INFO, 'registered service ', name, ' to: ', service,':',port, ' from ', name_env, ' and ', port_env)

  return { host = service, port = port }
end


function _M.new(options)
  local opts = options or {}
  local backend = cache_backend.new(opts.client or resty_backend)

  local http_client = http_ng.new({
    backend = backend,
    options = { ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') or false } }
  })

  local api_host = assert(opts.api_host or getenv('API_HOST'), 'need API_HOST')

  local services = {
    apicast_production = extract_service('apicast-production', 8080),
    apicast_staging = extract_service('apicast-staging', 8080),
    system_master = extract_service('system-master', 3000),
    system_provider = extract_service('system-provider', 3000),
    system_developer = extract_service('system-developer', 3000),
  }

  local cache_size = tonumber(resty_env.value('DOMAIN_CACHE_SIZE') or 100)
  local domain_cache = lrucache.new(cache_size)
  local domain_cache_ttl = tonumber(resty_env.value('DOMAIN_CACHE_TTL') or 60)

  return setmetatable({
    options = opts,
    http_client = http_client,
    api_host = api_host,
    services = services,
    domain_cache = domain_cache,
    domain_cache_ttl = domain_cache_ttl
  }, mt)
end

-- This function is used as a callback in a timer. The first param is
-- 'premature'. See https://github.com/openresty/lua-nginx-module#ngxtimerat
local function get_domain_info(_, domain, self)
  local url = resty_url.join(self.api_host, '/master/api/domain/', domain)

  local res = self.http_client.get(url)

  ngx.log(ngx.DEBUG, 'domain info for:  ', domain, ' from: ', url, ' status: ', res.status, ' body: ', res.body)

  if res.status == 200 then
    local domain_info = cjson.decode(res.body)
    self.domain_cache:set(domain, domain_info, self.domain_cache_ttl)

    return domain_info
  else
    ngx.log(ngx.WARN, 'could not get domain info for domain: ', domain, ' status: ', res.status)
    return { apicast = {} }, 'invalid'
  end
end

local function resolve(service)
  if not service then return nil, 'service not found' end

  local host = service.host
  local port = service.port
  local resolver = resty_resolver:instance()

  local servers = resolver:get_servers(host, { port = port })

  ngx.log(ngx.INFO, 'servers for host: ', host, ' found: ', servers)

  return servers
end

function _M:servers(host)
  local domain = host or _M.arg_host()

  local cached_domain_info, stale_domain_info = self.domain_cache:get(domain)

  local domain_info = cached_domain_info or
      stale_domain_info or
      get_domain_info(false, domain, self)

  -- When the cache info is stale, we use it, but also start a timer to refresh
  -- it. This avoids blocking the request.
  if stale_domain_info then
    local ok, err = ngx.timer.at(0, get_domain_info, domain, self)
    if not ok then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
      return
    end
  end

  local services = self.services

  local service

  if domain_info.master then
    service = services.system_master
  elseif domain_info.provider then
    service = services.system_provider
  elseif domain_info.developer then
    service = services.system_developer
  elseif domain_info.apicast.staging then
    service = services.apicast_staging
  elseif domain_info.apicast.production then
    service = services.apicast_production
  end

  return resolve(service)
end

function _M.arg_host()
  local ngx_var = ngx.var or {}

  return ngx_var.host
end

return _M
