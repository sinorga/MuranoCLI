--#ENDPOINT post /api/fire
-- luacheck: globals request response (magic variables from Murano)
response.code = 403

--#ENDPOINT put /api/fire/{code}
response.code = 500

--#ENDPOINT delete /api/fire/{code}
return 'ok'

-- vim: set ai sw=2 ts=2 :
