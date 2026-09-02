# Networking

## Port forwards

Forward **UDP** (and TCP only if you really enabled RCON) from the router to the Mac’s **LAN IPv4** address.

| Game | Game | Query | Other |
|---|---|---|---|
| Enshrouded | UDP `15636` | UDP `15637` | — |
| V Rising | UDP `27015` | UDP `27016` | TCP `25575` only if RCON is on |

Pick **one LAN IP** and keep it (DHCP reservation). If two games want the same port, change one of them *before* the first start.

## NAT hairpin

On many home routers, the public WAN IP **does not loop back** into the LAN. From the same Wi-Fi you get a timeout if you connect via the public IP.

Rule of thumb (Enshrouded and most UDP games):

- Same house / same LAN → connect to **LAN IP** (and the game port).
- Phone LTE, another country, a friend’s home → connect to **public IP**.

**V Rising exception:** Steam publishes the WAN address. From the same LAN, `IP:port` (LAN or WAN) often times out. Use the in-game Direct Connect **Steam GameServer ID** (`./serverctl.sh steam-id`). Players outside the house can use the in-game list by name. See below.

This is a router behaviour, not a Docker bug.

## How to join a passworded server

Steam overlay **Join** / “join from server list in Steam” often fails for passworded dedicated servers (especially V Rising). Use the **in-game** server browser (Play Online / dedicated list) and enter the password there.

**V Rising extra:** the game speaks Steam networking. From the same LAN as the host, Direct Connect by LAN/WAN IP frequently times out. Use the Steam GameServer ID from the dedicated-server log (`OnPolicyResponse - Game server SteamID`) in the in-game Direct Connect box. That ID is new every process start (`./serverctl.sh steam-id`). Players *outside* the house can still use the in-game list by server name; the advertised public IP is correct for them.

## Advertise on Steam / EOS

Listing the server publicly (`ListOnSteam`, `ListOnEOS`, Enshrouded query) requires:

- the query port forwarded (UDP);
- the process actually bound (check `./serverctl.sh logs`);
- no CGNAT in the way (if your ISP has no public IPv4, you need IPv6, a tunnel, or a friend joining via VPN).

## Firewall on the Mac

Docker Desktop publishes ports on all interfaces by default (`0.0.0.0`). macOS Application Firewall may still prompt. Allow Docker / the engine if joins fail from LAN with no router in the middle.
