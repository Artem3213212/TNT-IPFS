local http = require('http.client').new()
local json = require('json')

local api_prefix = 'http://127.0.0.1:5001'

local function get_config()
  local resp = http:post(api_prefix..'/api/v0/config/show')
  if resp.status == 200 then
    return json.decode(resp.body)
  else
    error(resp.reason)
  end
end

local function get_address()
  local config, err = get_config()
  if err ~= nil then
    return nil, err
  end

  return assert(config.gateway_pub_address, 'no gateway_pub_address in ipfs config')
end

local function pin_add(ipfs_id)
  local resp = http:post(api_prefix..'/api/v0/pin/add?arg='..ipfs_id)
  assert(resp.status == 200, resp.reason)
end

local function pin_rm(ipfs_id)
  local resp = http:post(api_prefix..'/api/v0/pin/rm?arg='..ipfs_id)
  assert(resp.status == 200, resp.reason)
end


return {
  get_config = get_config,
  get_address = get_address,
  pin_add = pin_add,
  pin_rm = pin_rm
}
