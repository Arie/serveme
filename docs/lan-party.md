# serveme at a LAN party

One Linux machine runs the serveme website and the TF2 servers. Players open
the website on the LAN, log in with Steam and reserve a server, the same way
they would on serveme.tf.

## What you need

- **git, curl and an SSH server** (`sudo apt install git curl openssh-server`).
  The website starts game servers over SSH to the machine it runs on.
- **Docker Engine and the Compose plugin**. The quickest install is
  `curl -fsSL https://get.docker.com | sh`.
- A user that can run Docker and `sudo`. Add yourself to the docker group with
  `sudo usermod -aG docker $USER`, then log out and back in.
- **Internet access**. Steam login and Steam itself need it, and game servers
  download maps from serveme.tf's fastdl.
- **A Steam Web API key** from https://steamcommunity.com/dev/apikey. The domain
  you enter there doesn't matter.
- About **25 GB of disk**, mostly for the TF2 server image, and about
  **1.5 GB of RAM per TF2 server**.

You don't need PayPal, Stripe, Cloudflare, Discord, MaxMind or a domain name.

## Starting it

```sh
git clone https://github.com/Arie/serveme.git
cd serveme
script/lan-quickstart
```

On the first run the script asks for:

- the LAN IP that players connect to (it suggests one)
- the Steam Web API key
- your SteamID64, so you become an admin (optional)
- how many TF2 servers can run at once

It saves the answers in `.env.lan`. Then it:

- builds the serveme image
- downloads the TF2 server image, about 15 GB
- downloads the DB-IP City Lite geolocation database
- sets up the database and starts everything

The first run takes a while. After that, starting takes seconds.

The website is then at `http://<LAN IP>:3000`.

To answer the questions ahead of time, set `LAN_IP`, `STEAM_API_KEY`,
`ADMIN_STEAM_UID` and `MAX_CONTAINERS` when you run the script.

## Ports

Players on the LAN need to reach:

| Port | What |
|---|---|
| 3000/tcp | the website |
| 27015/udp+tcp, 27025, 27035, ... | TF2 server 1, 2, 3, ... (one every 10 ports) |
| 27020/udp, 27030, 27040, ... | SourceTV of each server |

The game servers send their logs to UDP 39001 on the same machine, and the
website uses SSH on port 22 of the machine's LAN IP. If you run a firewall,
allow those from the machine itself.

## Connecting

Once a reservation's server has started, the reservation page shows an SDR
address (Steam Datagram Relay, `169.254.x.x`). Players outside the LAN can
join through it without any port forwarding. Players on the LAN are better off
connecting straight to the machine, for example `connect 192.168.1.10:27015`.
The first server is on 27015, the second on 27025, and so on.

## Everyday use

```sh
script/lan-quickstart                      # start (safe to run again)
script/lan-quickstart admin 7656119...     # make someone an admin
script/lan-quickstart logs                 # follow the website and worker logs
script/lan-quickstart stop                 # stop everything, keeps the data
```

To update, run `git pull` and then `script/lan-quickstart`. The script rebuilds
the image and migrates the database. The TF2 image updates itself: serveme
checks for a new one every 5 minutes and pulls it.

To start over, run `docker compose --env-file .env.lan down -v`. That deletes
the database and all logs. Then remove `.env.lan`, `lan/` and the
`serveme-lan` line in `~/.ssh/authorized_keys`.

## Differences from serveme.tf

- There are no donations, private servers or cloud VMs. Everyone gets the
  normal reservation length. To give someone longer reservations, an admin can
  add them to the Donators group.
- Map uploads are off. The map list is serveme.tf's, and the servers download
  maps from its fastdl.
- The firewall mitigations and Discord notifications are off. Players joining
  over SDR aren't kicked for having no history on this server.
- logs.tf and demos.tf uploads only happen when the person who made the
  reservation has set their own API key in their serveme settings.

## Troubleshooting

- **"SSH to ... failed"**: check that `ssh <you>@<LAN IP> docker version` works
  on the machine itself. The script adds the key in `lan/ssh` to your
  `~/.ssh/authorized_keys`.
- **A reservation hangs at "Creating server"**: `script/lan-quickstart logs`
  shows what the worker is doing, and `docker ps` shows the TF2 containers
  (`res-<id>-cloud-<id>`).
- **Steam login fails**: the machine needs to reach steamcommunity.com and
  api.steampowered.com, and the API key in `.env.lan` has to be valid.

Geolocation data: [DB-IP](https://db-ip.com), licensed under CC BY 4.0.
