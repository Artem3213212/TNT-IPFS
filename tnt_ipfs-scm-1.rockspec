package = 'tnt_ipfs'
version = 'scm-1'
source  = {
    url = '/dev/null',
}
-- Put any modules your app depends on here
dependencies = {
    'tarantool',
    'lua >= 5.1',
    'checks == 3.1.0-1',
    'cartridge == 2.7.3-1',
    'metrics == 0.12.0-1',
    'cartridge-cli-extensions == 1.1.1-1',
    'queue == 1.1.0'
}
build = {
    type = 'none';
}
