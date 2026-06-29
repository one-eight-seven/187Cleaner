fx_version 'cerulean'
game 'gta5'

author '187Scripts'
description '[187] Clandestine crime scene disposal — dual reputation, heat system, evidence decisions'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'framework/esx.lua',
    'framework/qbcore.lua',
    'framework/standalone.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/dist/index.html'

files {
    'html/dist/index.html',
    'html/dist/assets/index.js',
    'html/dist/assets/index.css',
    'html/dist/lib/187.css',
    'html/dist/lib/187.js'
}

-- optional_dependencies {
--     '187Banking'
-- }

escrow_ignore {
    'config.lua',
    'locales/en.lua',
    'framework/esx.lua',
    'framework/qbcore.lua',
    'framework/standalone.lua'
}

lua54 'yes'
