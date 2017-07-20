return {
  worker_processes = 'auto',
  port = '8080',
  nginx = require('lfs').currentdir() .. '/nginx',
  master_process = 'on',
  lua_code_cache = 'on',
}
