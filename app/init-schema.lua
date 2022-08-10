local queue = require('queue')

local function init_schema(is_master)
  local pinned = box.schema.space.create('pinned',{format={
      {'ipfs_id', 'string'},
      {'bucket_id', 'unsigned'}
    }, if_not_exists=true})

  pinned:create_index('primary', {parts={{1, 'string'}}, unique=true, if_not_exists=true})
  pinned:create_index('bucket_id', {parts={{2, 'unsigned'}}, unique=false, if_not_exists=true})

  if is_master then
    queue.create_tube('ipfs_add', 'fifottl', {if_not_exists = true})
    queue.create_tube('ipfs_remove', 'fifottl', {if_not_exists = true})
  end

  local pinned_no_shard = box.schema.space.create('pinned_no_shard',{format={
      {'ipfs_id', 'string'},
      {'status', 'string'}
    }, if_not_exists=true})

  pinned_no_shard:create_index('primary', {parts={{1, 'string'}}, unique=true, if_not_exists=true})

  local objects = box.schema.space.create('objects',{format={
      {'path', 'string'},
      {'bucket_id', 'unsigned'},
      {'name', 'string'},
      {'is_dir', 'boolean'},
      {'ipfs_id', 'string', is_nullable = true}
    }, if_not_exists=true})
  objects:create_index('primary', {parts={{1, 'string'},{3, 'string'}}, unique=true, if_not_exists=true})
  objects:create_index('bucket_id', {parts={{2, 'unsigned'}}, unique=false, if_not_exists=true})
end

return {
  init_schema=init_schema
}
