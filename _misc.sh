# This file is only for inclusion from install.sh and uninstall.sh

GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

print_for_log() {
    printf "${WHITE}$1${NC}\n"
}

print_for_log2() {
    printf "${GREEN}$1${NC}\n"
}
