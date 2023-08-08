fx_version 'bodacious'
game 'gta5'

author 'BryaN'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}