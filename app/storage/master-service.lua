local queue = require('queue')
local fiber = require('fiber')
local ipfs = require('app.ipfs')
local log = require('log')
local cartridge = require('cartridge')
local cartridge_lua_api_topology = require('cartridge.lua-api.topology')
local cartridge_pool = require('cartridge.pool')


local function get_curr_replicaset()
  local me = cartridge_lua_api_topology.get_self()
  return cartridge.admin_get_servers(me.uuid)[1].replicaset
end

local function call_on_whole_replicaset(func, params, options)
  local options = options or {}
  local servers_uri = {}
  for _, server in pairs(get_curr_replicaset().servers) do
    table.insert(servers_uri, server.uri)
  end

  local map_results, map_errors = cartridge_pool.map_call(func, params, {uri_list = servers_uri, timeout = options.timeout or 600})
  assert(map_errors == nil, map_errors)
  return map_results
end

local function on_replace(old, new, s, op)
  if old == nil then
    if new == nil then
      -- ничего не делаем
    else
      queue.tube.ipfs_add:put(new.ipfs_id, {delay=1})
    end
  else
    if new == nil then
      queue.tube.ipfs_remove:put(old.ipfs_id, {delay=1})
    else
      if old.ipfs_id ~= new.ipfs_id then
        queue.tube.ipfs_add:put(new.ipfs_id, {delay=1})
        queue.tube.ipfs_remove:put(old.ipfs_id, {delay=1})
      end
    end
  end
end

local ran = false

local function add_queue_worker()
  while ran do
    local task = queue.tube.ipfs_add:take()

    -- проверяем актуально ли задание
    local p = box.space.pinned:get(task[3])
    local pns = box.space.pinned_no_shard:get(task[3])
    if p == nil or pns ~= nil then
      queue.tube.ipfs_add:ack(task[1])
    else
      -- пытаемся запинить
      local ok, err = pcall(function()
          call_on_whole_replicaset('ipfs.internal.pin_add', {task[3]})
        end)

      if ok then -- удалось
        box.space.pinned_no_shard:put({task[3], 'PINNED'})
        queue.tube.ipfs_add:ack(task[1])
      else -- не удалось
        log.error(err)
        queue.tube.ipfs_add:release(task[1], {delay=10})
      end
    end
  end
end

local function rm_queue_worker()
  while ran do
    local task = queue.tube.ipfs_remove:take()

    -- проверяем актуально ли задание
    local p = box.space.pinned:get(task[3])
    local pns = box.space.pinned_no_shard:get(task[3])
    if p ~= nil or pns == nil then
      queue.tube.ipfs_add:ack(task[1])
    else
      local ok, err

      -- проверяем появился ли объект на новом месте
      ok, err = pcall(function()
          local pns = box.space.pinned_no_shard:get(task[3])
          if pns and pns.status == 'PINNED' then
            -- проверяем появился ли пин на новом месте
            local bucket_id = vshard.router.bucket_id_mpcrc32(task[3])
            assert(vshard.router.callro(bucket_id, 'ipfs.pin_status', {task[3]}) == 'Pinned')
          end
        end)

      if ok == nil then --рано распинивать
        queue.tube.ipfs_remove:release(task[1], {delay=10})
      else -- пытаемся распинить
        ok, err = pcall(function()
          call_on_whole_replicaset('ipfs.internal.pin_rm', {task[3]})
        end)

        if ok ~= nil then -- удалось
          box.space.pinned_no_shard:delete(task[3])
          queue.tube.ipfs_remove:ack(task[1])
        else -- не удалось
          log.error(err)
          queue.tube.ipfs_remove:release(task[1], {delay=10})
        end
      end
    end
  end
end

local function activate()
  if not ran then
    -- запускаем воркеры
    ran = true
    fiber.create(add_queue_worker)
    fiber.create(rm_queue_worker)

    -- включаем триггеры
    if #box.space.pinned:on_replace() == 0 then
      box.space.pinned:on_replace(on_replace)
    end
  end
end

local function deactivate()
  if ran then
    -- останавливаем воркеры
    ran = false

    -- выключаем триггеры
    if #box.space.pinned:on_replace() == 1 then
      box.space.pinned:on_replace(nil, on_replace)
    end
  end
end

return {
  activate = activate,
  deactivate = deactivate
}
