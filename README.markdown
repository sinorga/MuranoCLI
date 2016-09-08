# MrMurano

[![Gem Version](https://badge.fury.io/rb/MrMurano.svg)](https://badge.fury.io/rb/MrMurano)
[![Build Status](https://travis-ci.org/tadpol/MrMurano.svg?branch=master)](https://travis-ci.org/tadpol/MrMurano)

Do more from the command line with [Murano](https://exosite.com/platform/)

## Usage

To start from an existing project in Murano
```
mkdir myproject
cd myproject
mr config solution.id XXXXXX
mr syncdown -V
```

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

## Features

### Logs

You can monitor the log messages from your solution with the `mr logs --follow`.
Or quickly get the last few with `mr logs`

MrMurano does a few things to make your log output easier to follow.
- Adds color to easily see where each log message starts.
- Reformats the timestamps to be in local time.
- Finds JSON blobs and pretty prints them.

All of these can be toggled with command line options.

### Keystore

To aid with debugging, MrMurano has direct access to a solution's Keystore service.

To see all of the keys in the current solution: `mr keystore` 

### Timeseries

To aid with debugging, MrMurano has direct access to a solution's Timeseries service.


### Sub-directories

For the endpoints, modules, and eventhandlers directories. The can contain both
files or a sub-directory of files.  This allows for keeping common things grouped
together.  Or adding a git submodule in to manage reusable chunks.



### Bundles

MrMuanro allows adding bundles of resources to your project.

A Bundle is a group of modules, endpoints, and static files.

Bundles live in the 'bundle' directory.  Each bundle is a directory that matches
the layout of a project. (with directories for endpoints, modules, files, etc)

The items in bundles are layered by sorting the bundle names. Then your project's
items are layered on top.  This builds the list of what is synced.  It also allows
you to override things that are in a bundle from you project.


