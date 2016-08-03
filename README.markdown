# MrMurano

[![Gem Version](https://badge.fury.io/rb/MrMurano.svg)](https://badge.fury.io/rb/MrMurano)

Do more from the command line with [Murano](https://exosite.com/platform/)

## Usage

To start from an existing project in Murano
```
mkdir myproject
cd myproject
mr syncdown -same
```

Do stuff, see what changed: `mr status -same` or `mr diff -same`.
Then deploy `mr syncup -same`



## Install

```
> gem install MrMurano
```



## Bundles

MrMuanro allows adding bundles of resources to your project.

A Bundle is a group of modules, endpoints, static files and the other things.  

Bundles live in the 'bundle' directory.  Each bundle is a directory that matches
the layout of a project. (with directories for endpoints, modules, files, etc)

The items in bundles are layered by sorting the bundle names. Then your project's
items are layered on top.  This builds the list of what is synced.


