# GithubからVSCodeの設定ファイルをダウンロードして配置する
$VerbosePreference = 'Continue'
wget https://github.com/IzumiSy/dotfiles/raw/master/vscode/settings.json -O ~/AppData/Roaming/Code/User/settings.json
wget https://github.com/IzumiSy/dotfiles/raw/master/vscode/keybindings.json -O ~/AppData/Roaming/Code/User/keybindings.json
