

# Every sub-command will --help

# Start anew
- Clone project: `git clone https://github.com/tadpol/GWE-Multitool.git demo01`
- `cd demo01`

- Pick a bussiness: `mr business list`
- Set it: `mr config business.id ZZZZZZZZZ`

- Create a product: `mr product create myawesomeproduct`
- Save the result: `mr config product.id YYYYYYYYY`

- Set the product definition: `mr config product.spec gwe-multitool.yaml`
- Set the directory to look for specs. `mr config location.specs spec`
- Sync the product definition up: `mr syncup -V --specs`

- Create a solution: `mr solution create myawesomesolution`
- Save the result: `mr config solution.id XXXXXX`
- Assign the product to the solution: `mr assign set`

# What got configured?
`mr config --dump`






# <voice type='orc'>Work Work</voice>

- What is going to change? `mr status`
- Sync solution code up: `mr syncup -V`

- Change a file
- What is going to change? `mr status`
- Details of change: `mr diff`




# Devices
- Add a real device: `mr product device enable 42:42:42:42:42:42`
- !!!cheet and activate by hand: `mr product device activate 42:42:42:42:42:42`
- Which resources are there? `mr product spec pull`
- What did the device write to that one resource?
  `mr product device read 42:42:42:42:42:42 update_interval`
- `mr product device write 42:42:42:42:42:42 update_interval 300`



# Multiple configs
Because Developing, Staging, Production.

Set addition config file to load with `MR_CONFIGFILE`

Also supports '.env'




# Device Content Area

See GWE.





# Debugging

## Logs
- `mr logs`
- `mr logs --follow`






## Keystore
### What is in the Keystore?
`mr keystore list`

### Write and Read a Key
- `mr keystore set test greebled`
- `mr keystore get test`

### Write to a Set
- `mr keystore command sadd myset greebled`
Or any other supported Redis command.

### Remove just the ones with 'socketmap'
`mr keystore list | grep socketmap | xargs -L1 mr keystore delete`




## TSDB

- `mr tsdb list metrics`
- `mr tsdb list tags`
- `mr tsdb query @sn=1 temp0`
- `mr tsdb query @sn=1 temp0 --limit=4`
- `mr tsdb query @sn=1 --limit=10 -c outformat=csv --epoch ms`



