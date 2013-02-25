# FakkelBrigade server reservations [![Build Status](https://secure.travis-ci.org/Arie/serveme.png)](http://travis-ci.org/Arie/serveme) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/Arie/serveme) [![Coverage Status](https://coveralls.io/repos/Arie/serveme/badge.png?branch=master)](https://coveralls.io/r/Arie/serveme)

A web-interface to reserve TF2 gameservers

## Requirements

* Ruby, preferbly 1.9, but other versions might work. You should use [ruby-build](https://github.com/sstephenson/ruby-build/) to install Ruby.
* A Source game dedicated server installation, only tested with TF2 on linux for now. 
* A Steam API key for user sign in
* Memcached

## Installation
1. Make sure you've installed the requirements.
2. Review the yaml files in the `config` directory.
3. Enter your Steam API key in config/initializers/steam.rb: `STEAM_WEB_API_KEY = your_api_key_here`
4. Install the required gems using bundler: `gem install bundler && bundle`
5. Edit the seed data in db/seeds.rb
6. Setup and migrate the databases: rake db:create db:migrate db:seed RAILS_ENV=production
7. Setup a cronjob to deal with the reservations, here's an example: `*/1 * * * * /bin/bash -l -c 'cd /path/to/the/application; bundle exec rake environment reservations:end reservations:start RAILS_ENV=production' >/dev/null 2>&1`
8. Start the webserver: `thin -C config/thin.yml start`


## Servers
There's currently no web interface for adding/editing servers (pull requests welcome). So you'll have to enter them manually in the database or using the rails console.

Here's how you add a local server:
```ruby
Server.create(:name => "Name",
              :ip:  => "server_ip_or_hostname",
              :port => "server_port",
              :path => "/absolute/path/on/file/system")
```
The local servers should run with the same user as the web application, if you don't like this, use the ssh interface for managing 'remote' servers.

And this is how you add a remote server:

```ruby
Server.create(:name => "Name",
              :ip:  => "server_ip_or_hostname",
              :port => "server_port",
              :path => "/absolute/path/on/file/system",
              :type => "SshServer")
```

The user running the web application needs to be able to ssh to the remote server, you should use passwordless key-based authorization for this, add an entry in ~/.ssh/config for each remote machine. 
```
Host server_ip_or_hostname
  Hostname server_ip_or_hostname
  Port remote_ssh_port_if_not_22
  User remote_user
  IdentityFile ~/.ssh/id_rsa_for_remote_server
```
