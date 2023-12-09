fx_version 'cerulean'
game 'gta5'

author 'BryaN'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'locales/*.json',
    'config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}