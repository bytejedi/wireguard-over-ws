# wireguard-over-ws

### newyork1 server side
- [/etc/wireguard/wg0.conf](./server/wg0.conf)
- [/lib/systemd/system/wstunnel.service](./server/wstunnel.service)
- [/etc/nginx/nginx.conf](./server/nginx.conf)

### macOS client side
#### setup
1. brew install wireguard-tools
2. cd ~
3. mkdir .wstunnel
4. download https://github.com/erebe/wstunnel
5. mv wstunnel ~/.wstunnel
6. cp client/newyork1.wstunnel ~/.wstunnel
7. sudo cp client/wgoverws.sh /usr/local/bin/wgoverws.sh
8. sudo chmod +x /usr/local/bin/wgoverws.sh
9. sudo cp client/newyork1.conf /etc/wireguard/newyork1.conf
10. sudo chmod 600 /etc/wireguard/newyork1.conf

#### up
1. sudo wg-quick up newyork1

#### down
1. sudo wg-quick down newyork1
