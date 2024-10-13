$Env:KULALA_ROOT_DIR = (Get-Location).Path

if (!(Test-Path .tests)) {
  mkdir .tests
}

cd .tests

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

if (!(Test-Path ~/scoop)) {
  Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

  scoop install main/git
  scoop install main/neovim@0.10.2
}

if (!(Test-Path luajit-for-win64-0.0.2)) {
  Invoke-RestMethod -Uri https://github.com/mistweaverco/luajit-for-win64/archive/refs/tags/v0.0.2.zip -outfile luajit.zip
  7z x luajit.zip
  RM luajit.zip
  cd luajit-for-win64-0.0.2
  .\luajit-for-win64.cmd
}

$Env:KULALA_LUA_DIR = (Get-Location).Path

$Env:PATH = "$Env:KULALA_LUA_DIR\tools\cmd;$Env:KULALA_LUA_DIR\tools\PortableGit\mingw64\bin;$Env:KULALA_LUA_DIR\tools\PortableGit\usr\bin;$Env:KULALA_LUA_DIR\tools\mingw\bin;$Env:KULALA_LUA_DIR\lib;$Env:KULALA_LUA_DIR\bin;$Env:APPDATA\LJ4W\LuaRocks\bin;$Env:PATH"
$Env:LUA_PATH = "$Env:KULALA_LUA_DIR\lua\?.lua;$Env:KULALA_LUA_DIR\lua\?\init.lua;$Env:APPDATA\luarocks\share\lua\5.1\?.lua;$Env:APPDATA\luarocks\share\lua\5.1\?\init.lua;$Env:LUA_PATH"
$Env:LUA_CPATH = "$Env:APPDATA\luarocks;$Env:APPDATA\luarocks\lib\lua\5.1\?.dll;$Env:LUA_CPATH"

Write-Host "Path"
Write-Host $Env:PATH.Split(';')
Write-Host "LUA_PATH"
Write-Host $Env:LUA_PATH.Split(';')
Write-Host "LUA_CPATH"
Write-Host $Env:LUA_CPATH.Split(';')

luarocks install --lua-version 5.1 busted

# Persist the Environment Variables
"PATH=$Env:Path" >> $Env:GITHUB_ENV
"LUA_PATH=$Env:LUA_PATH" >> $Env:GITHUB_ENV
"LUA_CPATH=$Env:LUA_CPATH" >> $Env:GITHUB_ENV

cd $Env:KULALA_ROOT_DIR
