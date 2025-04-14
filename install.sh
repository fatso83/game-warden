#!/usr/bin/env bash
# Install the monitoring script

INSTALL_DIR="/opt/minecraft-monitor"

main(){
    trap "cleanup" EXIT 

    # kill existing process
    PID=$(pgrep -f "osascript.*minecraft-monitor") 
    if [[ "$PID" != "" ]]; then
        sudo kill "$PID"
    fi

    install_scripts
    install_crontab
}

cleanup(){
    rm root-crontab.tmp
}

install_scripts(){
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp -f ./config.plist keep-alive.sh  "$INSTALL_DIR/"
    sudo osacompile -o "$INSTALL_DIR/minecraft-monitor.scpt" minecraft-monitor.applescript 
    echo "Scripts installed to $INSTALL_DIR"
}

install_crontab(){
    # Install crontab
    cat > root-crontab.tmp << EOF
* * * * *  $INSTALL_DIR/keep-alive.sh
EOF

    sudo sudo crontab root-crontab.tmp

    echo "Installed the following crontab to root"
    cat root-crontab.tmp
}

main
