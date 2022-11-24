# GithubからVSCodeの設定ファイルをダウンロードして配置する
# 最新のmasterブランチのデータが欲しいのでno-cache指定にしておく
$VerbosePreference = 'Continue'
wget -Headers @{"Cache-Control"="no-cache"} https://github.com/IzumiSy/dotfiles/raw/master/vscode/settings.json -O ~/AppData/Roaming/Code/User/settings.json
wget -Headers @{"Cache-Control"="no-cache"} https://github.com/IzumiSy/dotfiles/raw/master/vscode/keybindings.json -O ~/AppData/Roaming/Code/User/keybindings.json
