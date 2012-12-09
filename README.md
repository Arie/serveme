# FakkelBrigade community gameserver interface

A web-interface to reserve TF2 gameservers

## Requirements

* Ruby, preferbly 1.9, but other versions might work. You should use [ruby-build](https://github.com/sstephenson/ruby-build/) to install Ruby.
* A Source game dedicated server installation, only tested with TF2 on linux for now. 
* A Steam API key for user sign in

## Installation
1. Make sure you've installed the requirements.
2. Review the yaml files in the `config` directory.
3. Enter your Steam API key in config/initializers/steam.rb: `STEAM_WEB_API_KEY = your_api_key_here`
4. Install the required gems using bundler: `gem install bundler && bundle`
5. Edit the seed data in db/seeds.rb
6. Setup and migrate the databases: rake db:create db:migrate db:seed RAILS_ENV=production
7. Start the webserver: `thin -C config/thin.yml start`