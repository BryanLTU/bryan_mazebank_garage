fx_version 'cerulean'
game 'gta5'

author 'BryaN'

shared_script 'config.lua'
client_scripts {
    'client/*.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}