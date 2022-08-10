#!/usr/bin/env bash

my_ip="93.100.96.36"

for i in 1 2 3 4 5; do
  docker-compose exec "tnt-ipfs$i" curl --request POST -L --url "http://127.0.0.1:5001/api/v0/config?arg=gateway_pub_address&arg=http://192.168.1.69:808$i"
  docker-compose exec "tnt-ipfs$i" curl --request POST -L --url "http://127.0.0.1:5001/api/v0/config?arg=Addresses.API&arg=/ip4/0.0.0.0/tcp/5001"
  docker-compose exec "tnt-ipfs$i" curl --request POST -L --url "http://127.0.0.1:5001/api/v0/config?arg=Addresses.Announce&arg=\[\"/ip4/$my_ip/tcp/400$i\"\]&json=1"
  docker-compose exec "tnt-ipfs$i" curl --request POST -L --url "http://127.0.0.1:5001/api/v0/config?arg=Addresses.Gateway&arg=/ip4/0.0.0.0/tcp/8081"
  docker-compose exec "tnt-ipfs$i" curl --request POST -L --url "http://127.0.0.1:5001/api/v0/config/show"
  docker-compose restart "tnt-ipfs$i"
done
