setx /M KULALA_ROOT_DIR (Get-Location).Path
setx /M LUAJIT_FOR_WIN_REPO \"luajit-for-win64\"
setx /M LUAJIT_FOR_WIN_RELEASE \"0.0.2\"

cd .tests

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# required before add extras
scoop install main/git

# add for extras suggested by neovim
scoop bucket add extras

scoop install extras/vcredist2022
scoop install main/neovim@0.10.2

Invoke-RestMethod -Uri \"https://github.com/mistweaverco/$Env:LUAJIT_FOR_WIN_REPO/archive/refs/tags/v$Env:LUAJIT_FOR_WIN_RELEASE.zip\" -outfile luajit.zip
7z x luajit.zip

RM luajit.zip

cd \"$Env:LUAJIT_FOR_WIN_REPO-$Env:LUAJIT_FOR_WIN_RELEASE\"

.\luajit-for-win64.cmd

setx /M KULALA_LUA_DIR (Get-Location).Path

setx /M PATH \"$Env:KULALA_LUA_DIR\tools\cmd;$Env:KULALA_LUA_DIR\tools\PortableGit\mingw64\bin;$Env:KULALA_LUA_DIR\tools\PortableGit\usr\bin;$Env:KULALA_LUA_DIR\tools\mingw\bin;$Env:KULALA_LUA_DIR\lib;$Env:KULALA_LUA_DIR\bin;$Env:APPDATA\LJ4W\LuaRocks\bin;$Env:path\"
setx /M LUA_PATH \"$Env:KULALA_LUA_DIR\lua\?.lua;$Env:KULALA_LUA_DIR\lua\?\init.lua;$Env:APPDATA\luarocks\share\lua\5.1\?.lua;$Env:APPDATA\luarocks\share\lua\5.1\?\init.lua;$Env:LUA_PATH\"
setx /M LUA_CPATH \"$Env:APPDATA\luarocks;$Env:APPDATA\luarocks\lib\lua\5.1\?.dll;$Env:LUA_CPATH\"

Write-Host \"Path: $Env:PATH.Split(';')\"
Write-Host \"LUA_PATH: $Env:LUA_PATH.Split(';')\"
Write-Host \"LUA_CPATH: $Env:LUA_CPATH.Split(';')\"

luarocks install --lua-version 5.1 busted

cd $Env:KULALA_ROOT_DIR
