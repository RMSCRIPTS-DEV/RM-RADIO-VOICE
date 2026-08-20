server_script '@ElectronAC/src/include/server.lua'
client_script '@ElectronAC/src/include/client.lua'
fx_version 'cerulean'
game 'gta5'

name 'at-radio'
description 'Radio resource for AtLeast'
repository 'https://github.com/Qbox-project/qbx_radio'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/earpiece.lua',
}

server_script 'server/main.lua'

dependencies {
    'pma-voice',
    'ox_inventory',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
    'config/shared.lua',
    'config/client.lua',
    'locales/*.json'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
