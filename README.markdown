# MrMurano

[![Gem Version](https://badge.fury.io/rb/MrMurano.svg)](https://badge.fury.io/rb/MrMurano)
[![Build Status](https://travis-ci.org/tadpol/MrMurano.svg?branch=master)](https://travis-ci.org/tadpol/MrMurano)

Do more from the command line with [Murano](https://exosite.com/platform/)

MrMurano is the command-line tool that interacts with Murano and makes different
tasks easier. MrMurano makes it easy to deploy code to a solution, import many
product definitions at once, set up endpoints and APIs, and more.

MrMurano works around the idea of syncing, much like rsync.  Files from your working
directory are synced up (or down) from Murano.

## Usage

### To start from an existing project in Murano
```
mkdir myproject
cd myproject
mr config solution.id XXXXXX
mr syncdown -V
```

Do stuff, see what changed: `mr status` or `mr diff`.
Then deploy with `mr syncup`

### To start a brand new project
There are a few steps and pieces to getting a solution with a product up and
running in Murano. Here is the list.

- Pick a bussiness: `mr account --business`
- Set it: `mr config business.id ZZZZZZZZZ`
- Create a product: `mr product create myawesomeproduct`
- Save the result: `mr config product.id YYYYYYYYY`
- Set the product definition: `mr config product.spec prd.spec`
- Add resource aliases to specs/prd.spec
- Sync the product definition up: `mr syncup -V --specs`
- Create a solution: `mr solution create myawesomesolution`
- Save the result: `mr config solution.id XXXXXX`
- Sync solution code up: `mr syncup -V`
- Assign the product to the solution: `mr assign set`

Do stuff, see what changed: `mr status` or `mr diff`.
Then deploy with `mr syncup`

## Install

```
> gem install MrMurano
```
Or
```
> gem update MrMurano
```

You will likely need to be root for the above commands.  If you would rather not
install as root, you can install gems in the user directory.

```
> gem install MrMurano --user-install
```

Your `PATH` may need to be updated to find the installed `mr` command.  See the
[Ruby Gem FAQ](http://guides.rubygems.org/faqs/#user-install).  In short, you need
to add the output of `ruby -rubygems -e 'puts Gem.user_dir'` to your `PATH`.

## Features

### Logs

You can monitor the log messages from your solution with the `mr logs --follow`.
Or quickly get the last few with `mr logs`

MrMurano does a few things to make your log output easier to follow.
- Adds color to easily see where each log message starts.
- Reformats the timestamps to be in local time.
- Finds JSON blobs and pretty prints them.

All of these can be toggled with command line options.

### MR_CONFIGFILE environment and Dotenv

The environment variable `MR_CONFIGFILE` is checked for an additional config to
load.  This in conjuction with dotenv support, allows for easily switching between
development, staging, and production setups.

To use this, write the three solution ids into `.mrmurano.dev`, `.mrmurano.stg`,
and `.mrmurano.prod`. Then write the `.env` file to point at the system you're
currently working on.

The files for this are then:
```
cat >> .mrmurano.dev <<EOF
[solution]
id=AAAAAAAA
EOF

cat >> .mrmurano.stg <<EOF
[solution]
id=BBBBBBBB
EOF

cat >> .mrmurano.prod <<EOF
[solution]
id=CCCCCCCC
EOF

cat >> .env <<EOF
MR_CONFIGFILE=.mrmurano.dev
EOF
```

This also allows for keeping private things in a seperate config file and having
the shared things checked into source control.

### Keystore

To aid with debugging, MrMurano has direct access to a solution's Keystore service.

To see all of the keys in the current solution: `mr keystore`

### Timeseries

To aid with debugging, MrMurano has direct access to a solution's Timeseries service.

### Product Content Area

MrMurano can manage the content area for a product.  This area is a place to store
files for use by devices.  Typically holding firmware images for Over-The-Air
updating.  Although any kind of fleet wide data that devices may need to download
can be stored here.

Once the `product.id` is set, the content for that product can be accessed with the
following commands:
```
> mr content list
> mr content upload
> mr content info
> mr content delete
> mr content download
```

Call them with `--help` for details.

### ZSH tab completion

Basic completion support for zsh.

### Sub-directories

For the endpoints, modules, and eventhandlers directories. The can contain both
files or a sub-directory of files.  This allows for keeping common things grouped
together.  Or adding a git submodule in to manage reusable chunks.

So, as an example, your project could be like:
```
endpoints
endpoints/get_-v1-data-averaged.lua
endpoints/get_-v1-data-cupsDrank.lua
endpoints/get_-v1-data-latest.lua
endpoints/statusboard-data.lua
endpoints/users
endpoints/users/get_-session.lua
endpoints/users/get_-v1-verify-code.lua
endpoints/users/patch_-v1-user.lua
endpoints/users/post_-session.lua
endpoints/users/post_-v1-pushtoken.lua
endpoints/users/put_-v1-user-email.lua
eventhandlers
eventhandlers/product.lua
eventhandlers/timer_timer.lua
files
files/batteryMeter.svg
files/index.html
files/meter.html
modules
modules/TSQ
modules/TSQ/func_field_quote_test.lua
modules/TSQ/isadate_test.lua
modules/TSQ/README.md
modules/TSQ/results_test.lua
modules/TSQ/select_fields_test.lua
modules/TSQ/tsq-1.2-2.rockspec
modules/TSQ/tsq.lua
modules/TSQ/tsq_test.lua
modules/TSQ/tsw.lua
modules/TSQ/tsw_test.lua
modules/users.lua
modules/util.lua
spec
spec/cico.murano.spec
```


### Bundles

MrMuanro allows adding bundles of resources to your project.

A Bundle is a group of modules, endpoints, and static files.

Bundles live in the 'bundle' directory.  Each bundle is a directory that matches
the layout of a project. (with directories for endpoints, modules, files, etc)

The items in bundles are layered by sorting the bundle names. Then your project's
items are layered on top.  This builds the list of what is synced.  It also allows
you to override things that are in a bundle from you project.


