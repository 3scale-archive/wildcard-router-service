local _M = {
  _VERSION = '0.1'
}

local mt = {
  __index = _M
}

function _M.new(options)
  return setmetatable({}, mt)
end

function _M.get_apicast()
  -- get provider id
  -- load apicast url from system api
end

function _M.provider_id()
  local arg_host = _M.arg_host()
  if not arg_host then
    return false
  end

  local provider_id_part = ngx_re.split(arg_host, '[%.]')[1]
  if not provider_id_part then
    return false
  end

  local parts = ngx_re.split(provider_id_part, '-')
  return parts[#parts]
end

function _M.arg_host()
  local ngx_var = ngx.var or {}

  return ngx_var.arg_host
end

return _M
