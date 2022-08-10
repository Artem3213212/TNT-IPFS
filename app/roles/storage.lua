local init_schema = require('app.init-schema')
local storage_api = require('app.storage.api')
local storage_master_service = require('app.storage.master-service')

local function init(opts) -- luacheck: no unused args
  init_schema.init_schema(opts.is_master)

  rawset(_G, 'ipfs', storage_api.ipfs)
  rawset(_G, 'storage', storage_api.storage)

  if opts.is_master then
    storage_master_service.activate()
  else
    storage_master_service.deactivate()
  end

  return true
end

local function stop() -- luacheck: no unused args
  rawset(_G, 'ipfs')
  rawset(_G, 'storage')

  storage_master_service.deactivate()

  return true
end

local function apply_config(conf, opts) -- luacheck: no unused args
  init_schema.init_schema(opts.is_master)

  if opts.is_master then
    storage_master_service.activate()
  else
    storage_master_service.deactivate()
  end
  return true
end

return {
  role_name = 'app.roles.storage',
  init = init,
  apply_config = apply_config,
  stop = stop,
  dependencies = {'cartridge.roles.vshard-storage', 'app.roles.router'},
}
