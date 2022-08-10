local ipfs = require('app.ipfs')

local function get_local_ipfs_addr()
  return ipfs.get_address()
end

local function pin_write(tuple)
  box.space.pinned:put(tuple)
end

local function pin_delete(ipfs_id)
  box.space.pinned_no_shard:put({ipfs_id, 'CAN_UNPIN'})
  box.space.pinned:delete(ipfs_id)
end

local function pin_status(ipfs_id)
  if box.space.pinned:get(ipfs_id) ~= nil then
    -- Want to pin
    if box.space.pinned_no_shard:get(ipfs_id) ~= nil then
      return 'Pinned'
    else
      return 'Wait pining'
    end
  else
    -- Want to unpin
    local pns = box.space.pinned_no_shard:get(ipfs_id)
    if pns ~= nil then
      if pns.status == 'CAN_UNPIN' then
        return 'Wait unpining'
      else
        return 'Wait reshard'
      end
    else
      return 'Not found'
    end
  end
end


local function storage_add(path,bucket_id,name,is_dir,ipfs_id)
  if is_dir then
    box.space.objects:put({path,bucket_id,name,true})
  else
    box.space.objects:put({path,bucket_id,name,false,ipfs_id})
  end
end

local function storage_del(path,name)
  local data = box.space.objects:delete({path,name})
  assert(data ~= nil)
  return data:tomap({names_only=true})
end

local function storage_get(path,name)
  local data = box.space.objects:get({path,name})
  assert(data ~= nil)
  return data:tomap({names_only=true})
end

local function storage_ls(path)
  local result = {}
  for _,i in box.space.objects:pairs({path}) do
    table.insert(result, {name = i.name, is_dir = i.is_dir})
  end
  return result
end

return {
  ipfs = {
    get_local_ipfs_addr = get_local_ipfs_addr,
    pin_write = pin_write,
    pin_delete = pin_delete,
    pin_status = pin_status,

    internal = {
      pin_add = ipfs.pin_add,
      pin_rm = ipfs.pin_rm
    }
  },
  storage = {
    add = storage_add,
    del = storage_del,
    get = storage_get,
    ls = storage_ls
  }
}
