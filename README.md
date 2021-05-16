# [FakkelBrigade server reservations](http://serveme.tf)


A web-interface to reserve TF2 gameservers

## Requirements

* Ruby, preferbly 2.6, but other versions might work. You should use [ruby-build](https://github.com/sstephenson/ruby-build/) to install Ruby.
* A Steam API key for user sign in
* Redis

### Server Requirements
* A Source game dedicated server installation, only tested with TF2 on linux for now.
* Gameserver started with `-port PORTNUMBER -autoupdate` in the startup line
* [libmaxminddb](https://github.com/maxmind/libmaxminddb), for GeoIP lookups. Or you can configure another one in the
  [geocoder initializer](https://github.com/alexreisner/geocoder)

## Running localy
1. Make sure you've installed the requirements.
2. Review the yaml files in the `config` directory.
3. Get a steam api key https://steamcommunity.com/dev/apikey
4. Create a new file at `config/initializers/steam.rb` with the folowing:
```ruby
STEAM_WEB_API_KEY = '<your_api_key_here>'
```
5. Go to https://dev.maxmind.com/geoip/geoip2/geolite2/ and download the `GeoLite2 City` DB file. unzip and place in `/doc/` folder.
6. Install required librarys for nokogiri [(doc can be found here)](http://www.nokogiri.org/tutorials/installing_nokogiri.html#install_with_included_libraries__recommended_)
7. Install the required gems using bundler: `gem install bundler && bundle` Hint you may need to install some header files for  for
8. Edit the seed data in db/seeds.rb i.e the servers list
9. Setup and migrate the databases: rake db:create db:migrate db:seed RAILS_ENV=development
10. Start the webserver: `rails s`
11. Add `exec reservation.cfg` to the server.cfg of the gameserver


## Servers
There's currently no web interface for adding/editing servers (pull requests welcome). So you'll have to enter them manually in the database or using the rails console.

Here's how you add a local server:
```ruby
LocalServer.create(:name => "Name",
                   :ip   => "server_ip_or_hostname",
                   :port => "server_port",
                   :path => "/absolute/path/on/file/system")
```
The local servers should run with the same user as the web application, if you don't like this, use the ssh interface for managing 'remote' servers.

And this is how you add a remote server:

```ruby
SshServer.create(:name => "Name",
                 :ip   => "server_ip_or_hostname",
                 :port => "server_port",
                 :path => "/absolute/path/on/file/system")
```

The user running the web application needs to be able to ssh to the remote server, you should use passwordless key-based authorization for this, add an entry in ~/.ssh/config for each remote machine.
```
Host server_ip_or_hostname
  Hostname server_ip_or_hostname
  Port remote_ssh_port_if_not_22
  User remote_user
  IdentityFile ~/.ssh/id_rsa_for_remote_server
```

## API
There's a simple JSON API to create and stop reservations. It typically returns a prefilled JSON response, which you can edit and send to one of the URLs listed in the "actions".

### Authentication
All requests should have the API key as the HTTP request parameter api_key or as a request header `Authorization: Token token=api-token-here`. Donators can find the API key in their settings page, or you can contact me to get yours.

### Step 1
```shell
curl -X GET -H "Content-Type: application/json" 'https://serveme.tf/api/reservations/new?api_key=your_api_key'
```

This will return a prefilled JSON response, which you can POST to the action "find_servers"
```
{
  "reservation": {
    "starts_at":"2014-04-13T18:00:20.415+02:00",
    "ends_at":"2014-04-13T20:00:20.415+02:00"
  },
  "actions": {
    "find_servers": "https://serveme.tf/api/reservations/find_servers"
  }
}
```

### Step 2
POST a reservation with starts_at and ends_at filled in to find_servers.
```shell
curl -X POST -H "Content-Type: application/json" -d '{"reservation":{"starts_at":"2014-04-13T18:00:20.415+02:00","ends_at":"2014-04-13T20:00:20.415+02:00"}}' 'https://serveme.tf/api/reservations/find_servers?api_key=your_api_key'
```

This will return a prefilled JSON response with available servers, whitelists and server configs included:
```
{
  "reservation": {
    "starts_at": "2014-04-13T18:00:20.415+02:00",
    "ends_at": "2014-04-13T20:00:20.415+02:00",
    "server_id": null,
    "password": null,
    "rcon": null,
    "first_map": null,
    "tv_password": "tv",
    "tv_relaypassword": "tv",
    "server_config_id": null,
    "whitelist_id": null,
    "custom_whitelist_id": null,
    "auto_end": true
  },
  "servers": [
    {
      "id": 64,
      "name": "FritzBrigade #10",
      "location": {
        "id": 8,
        "name": "Germany",
        "flag": "de"
      }
    }
  ],
  "server_configs": [
    {
      "id": 2,
      "file": "etf2l_6v6"
    },
    {
      "id": 3,
      "file": "etf2l_9v9"
    }
  ],
  "whitelists": [
    {
      "id": 2,
      "file": "etf2l_whitelist_6v6.txt"
    },
    {
      "id": 3,
      "file": "etf2l_whitelist_9v9.txt"
    }
  ],
  "actions": {
    "create": "https://serveme.tf/api/reservations"
  }
}
```

### Step 3
POST a complete reservation to the "create" action
```shell
curl -X POST -H "Content-Type: application/json" -d '{"reservation":{"starts_at":"2014-04-13T18:00:20.415+02:00","ends_at":"2014-04-13T20:00:20.415+02:00","rcon":"foo","password":"bar","server_id":1337}}' 'https://serveme.tf/api/reservations?api_key=your_api_key'
```

If there's any errors, you'll get a HTTP 400 and a new prefilled reservation JSON with errors:
```
{
  "reservation": {
    "starts_at": "2014-04-13T18:00:20.415+02:00",
    "ends_at": "2014-04-13T20:00:20.415+02:00",
    "server_id": null,
    "password": "bar",
    "rcon": "foo",
    "first_map": null,
    "tv_password": "tv",
    "tv_relaypassword": "tv",
    "server_config_id": null,
    "whitelist_id": null,
    "custom_whitelist_id": null,
    "auto_end": true,
    "errors": {
      "server": {
        "error": "can't be blank"
      },
      "starts_at": {
        "error": "can't be more than 15 minutes in the past"
      }
    }
  },
  "actions": {
    "create": "https://serveme.tf/api/reservations"
  },
  "servers": [
    {
      "id": 64,
      "name": "FritzBrigade #10",
      "flag": "de"
    }
  ],
  "server_configs": [
    {
      "id": 19,
      "file": "wptf2l"
    }
  ],
  "whitelists": [
    {
      "id": 9,
      "file": "wp9v9_whitelist.txt"
    }
  ]
}
```

If everything went alright, you'll get a HTTP 200 and shown your reservation details:
```
{
  "reservation": {
    "starts_at": "2014-04-13T19:00:20.415+02:00",
    "ends_at": "2014-04-13T20:00:20.415+02:00",
    "server_id": 64,
    "password": "bar",
    "rcon": "foo",
    "first_map": null,
    "tv_password": "tv",
    "tv_relaypassword": "tv",
    "server_config_id": null,
    "whitelist_id": null,
    "custom_whitelist_id": null,
    "auto_end": true,
    "id": 12345,
    "last_number_of_players": 0,
    "inactive_minute_counter": 0,
    "logsecret": 298424416816498481223654962917404607282,
    "start_instantly": false,
    "end_instantly": false,
    "server": {
      "name": "Server name",
      "ip_and_port": "127.0.0.1:27015"
    },
    "errors": {}
  },
  "actions": {
    "delete": "https://serveme.tf/api/reservations/12345"
  }
}
```

### Step 4
After the match is over, you can end your reservation

First, you can check your reservation details:
```shell
curl -X GET -H "Content-Type: application/json" 'https://serveme.tf/api/reservations/12345?api_key=your_api_key'
```

This JSON response will tell you if the reservation hasn't ended by itself already with the "ended" boolean. If you want to end it yourself, you need to send a HTTP DELETE to the "delete" action URL:

```shell
curl -X DELETE -H "Content-Type: application/json" 'https://serveme.tf/api/reservations/12345?api_key=your_api_key'
```

The "delete" action will respond with a 204 if the reservation was deleted before it was started, else it will respond with a 200 and the reservation's information.
