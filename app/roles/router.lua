local cartridge = require('cartridge')
local vshard = require('vshard')
local json = require('json')

local function convert_path(full_path)
  local path, name = full_path:match("^(.*)/(.+)$")
  if not path then
    return '', full_path
  end
  return path, name
end

local function init(opts) -- luacheck: no unused args
  local httpd = assert(cartridge.service_get('httpd'), "Failed to get httpd service")
  httpd:route({method = 'GET', path = '/tnt_ipfs/pin/:ipfs_id', public = true}, function(req)
      local ipfs_id = req:stash('ipfs_id')
      local bucket_id = vshard.router.bucket_id_mpcrc32(ipfs_id)
      local gateway_addr, err = vshard.router.callbro(bucket_id, 'ipfs.get_local_ipfs_addr')
      if err ~= nil then
        return {
          status = 500,
          body = err
        }
      end
      return req:redirect_to(gateway_addr..'/ipfs/'..ipfs_id)
    end)

  httpd:route({method = 'PUT', path = '/tnt_ipfs/pin/:ipfs_id', public = true}, function(req)
      local ipfs_id = req:stash('ipfs_id')
      local bucket_id = vshard.router.bucket_id_mpcrc32(ipfs_id)
      local _, err = vshard.router.callrw(bucket_id, 'ipfs.pin_write', {{ipfs_id, bucket_id}})
      if err ~= nil then
        return {
          status = 500,
          body = err
        }
      end
      return {status = 200}
    end)

  httpd:route({method = 'DELETE', path = '/tnt_ipfs/pin/:ipfs_id', public = true}, function(req)
      local ipfs_id = req:stash('ipfs_id')
      local bucket_id = vshard.router.bucket_id_mpcrc32(ipfs_id)
      local _, err = vshard.router.callrw(bucket_id, 'ipfs.pin_delete', {ipfs_id})
      if err ~= nil then
        return {
          status = 500,
          body = err
        }
      end
      return {status = 200}
    end)

  httpd:route({method = 'GET', path = '/tnt_ipfs/pin/:ipfs_id/status', public = true}, function(req)
      local ipfs_id = req:stash('ipfs_id')
      local bucket_id = vshard.router.bucket_id_mpcrc32(ipfs_id)
      local pin_status, err = vshard.router.callro(bucket_id, 'ipfs.pin_status', {ipfs_id})
      if err ~= nil then
        return {
          status = 500,
          body = err
        }
      end
      return {
        status = 200,
        body = pin_status
      }
    end)


  httpd:route({method = 'PUT', path = '/tnt_ipfs/storage/*full_path', public = true}, function(req)
      local full_path = req:stash('full_path')
      local path, name = convert_path(full_path)
      local bucket_id = vshard.router.bucket_id_mpcrc32(path)
      local type = req:query_param('type')
      if type == 'dir' then
        local _, err = vshard.router.callrw(bucket_id, 'storage.add', {path, bucket_id, name, true})
        if err ~= nil then
          return {
            status = 500,
            body = err
          }
        end
        return {status = 200}
      elseif type == 'object' then
        local ipfs_id = req:query_param('ipfs_id')
        local bucket_id2 = vshard.router.bucket_id_mpcrc32(ipfs_id)
        local _, err = vshard.router.callrw(bucket_id2, 'ipfs.pin_write', {{ipfs_id, bucket_id2}})
        if err ~= nil then
          return {
            status = 500,
            body = err
          }
        end
        _, err = vshard.router.callrw(bucket_id, 'storage.add', {path, bucket_id, name, false, ipfs_id})
        if err ~= nil then
          return {
            status = 500,
            body = err
          }
        end
        return {status = 200}
      end
      return {status = 400}
    end)

  httpd:route({method = 'DELETE', path = '/tnt_ipfs/storage/*full_path', public = true}, function(req)
      local full_path = req:stash('full_path')
      local path, name = convert_path(full_path)
      local bucket_id = vshard.router.bucket_id_mpcrc32(path)
      local deleted, err = vshard.router.callrw(bucket_id, 'storage.del', {path, name})
      if deleted == nil or err ~= nil then
        return {
          status = 500,
          body = err
        }
      end
      if deleted.is_dir then
        return {status = 200}
      else
        bucket_id = vshard.router.bucket_id_mpcrc32(deleted.ipfs_id)
        local _, err2 = vshard.router.callrw(bucket_id, 'ipfs.pin_delete', {deleted.ipfs_id})
        if err2 ~= nil then
          return {
            status = 500,
            body = err2
          }
        end
        return {status = 200}
      end
    end)

  httpd:route({method = 'GET', path = '/tnt_ipfs/storage/*full_path', public = true}, function(req)
      local full_path = req:stash('full_path')
      local path, name = convert_path(full_path)
      local bucket_id = vshard.router.bucket_id_mpcrc32(path)
      local main_record, err
      if path == '' then --каталог в корне
        main_record = {is_dir=true}
      else
        main_record, err = vshard.router.callro(bucket_id, 'storage.get', {path,name})
        if err ~= nil then
          return {
            status = 500,
            body = err
          }
        end
        if main_record == nil then
          return {status = 404}
        end
      end
      if main_record.is_dir then
        bucket_id = vshard.router.bucket_id_mpcrc32(full_path)
        local result, err2 = vshard.router.callro(bucket_id, 'storage.ls', {full_path})
        if err2 ~= nil then
          return {
            status = 500,
            body = err2
          }
        end
        return {
          status = 200,
          body = json.encode(result)
        }
      else
        require('log').error({main_record})
        bucket_id = vshard.router.bucket_id_mpcrc32(main_record.ipfs_id)
        require('log').error({main_record,bucket_id})
        local gateway_addr, err2 = vshard.router.callbro(bucket_id, 'ipfs.get_local_ipfs_addr')
        require('log').error({main_record,bucket_id,gateway_addr,err2})
        if err2 ~= nil then
          return {
            status = 500,
            body = err2
          }
        end
        return req:redirect_to(gateway_addr..'/ipfs/'..main_record.ipfs_id)
      end
    end)

  return true
end

local function stop()
  return true
end

return {
  role_name = 'app.roles.router',
  init = init,
  stop = stop,
  dependencies = {'cartridge.roles.vshard-router'},
}
