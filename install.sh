#!/bin/bash

###############################################################################
# Raspberry Pi 5 Fan Control - Installation Script
# 
# This script installs the rpi5-fan-config tool system-wide
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Raspberry Pi 5 Fan Control - Installer${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

install_script() {
    print_info "Installing rpi5-fan-config..."
    
    if [ ! -f "rpi5-fan-config.sh" ]; then
        print_error "rpi5-fan-config.sh not found in current directory"
        exit 1
    fi
    
    # Copy script to /usr/local/bin
    cp rpi5-fan-config.sh /usr/local/bin/rpi5-fan-config
    chmod +x /usr/local/bin/rpi5-fan-config
    
    print_success "Script installed to /usr/local/bin/rpi5-fan-config"
}

install_man_page() {
    print_info "Creating man page..."
    
    mkdir -p /usr/local/share/man/man1
    
    cat > /usr/local/share/man/man1/rpi5-fan-config.1 << 'EOF'
.TH RPI5-FAN-CONFIG 1 "December 2025" "1.0" "Raspberry Pi 5 Fan Control"
.SH NAME
rpi5-fan-config \- Configure PWM fan control on Raspberry Pi 5
.SH SYNOPSIS
.B rpi5-fan-config
.SH DESCRIPTION
.B rpi5-fan-config
is an interactive tool for configuring the PWM fan control on Raspberry Pi 5.
It provides an easy-to-use menu interface for setting temperature thresholds
and fan speeds, similar to raspi-config.
.PP
The tool modifies /boot/firmware/config.txt to configure the fan control
parameters, which are applied at boot time by the Raspberry Pi firmware.
.SH OPTIONS
This tool does not take command-line options. All configuration is done
through the interactive menu.
.SH CONFIGURATION
Fan speed values range from 0 to 255 (PWM scale). As a rule of thumb,
divide the raw value by 2.5 to approximate the fan speed percentage.
.PP
Temperature values are specified in millidegrees Celsius:
.IP \(bu 2
30000 = 30°C
.IP \(bu 2
60000 = 60°C
.IP \(bu 2
75000 = 75°C
.SH PRESETS
.TP
.B QUIET
Minimal noise, moderate cooling. Suitable for office environments.
.TP
.B BALANCED
Recommended for most users. Good balance of cooling and noise.
.TP
.B PERFORMANCE
Maximum cooling with more noise. For heavy workloads and overclocking.
.TP
.B SILENT
Very quiet operation. For light workloads and media centers.
.SH FILES
.TP
.I /boot/firmware/config.txt
Main configuration file modified by this tool
.TP
.I /boot/firmware/config.txt.backup
Automatic backup created before changes
.SH EXAMPLES
Run the configuration tool:
.PP
.nf
.RS
sudo rpi5-fan-config
.RE
.fi
.SH SEE ALSO
raspi-config(1)
.SH AUTHOR
Created for Raspberry Pi 5 fan control configuration
.SH BUGS
Report bugs at: https://github.com/yourusername/rpi5-fan-control
EOF
    
    # Update man database
    if command -v mandb > /dev/null 2>&1; then
        mandb -q 2>/dev/null || true
    fi
    
    print_success "Man page installed"
}

create_desktop_entry() {
    print_info "Creating desktop entry..."
    
    mkdir -p /usr/local/share/applications
    
    cat > /usr/local/share/applications/rpi5-fan-config.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Raspberry Pi 5 Fan Control
Comment=Configure PWM fan control on Raspberry Pi 5
Exec=sudo -A rpi5-fan-config
Icon=preferences-system
Terminal=true
Categories=System;Settings;
Keywords=raspberry;pi;fan;cooling;temperature;
EOF
    
    print_success "Desktop entry created"
}

install_bash_completion() {
    print_info "Installing bash completion..."
    
    mkdir -p /etc/bash_completion.d
    
    cat > /etc/bash_completion.d/rpi5-fan-config << 'EOF'
# bash completion for rpi5-fan-config

_rpi5_fan_config() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # No options currently, but this is here for future expansion
    opts=""
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _rpi5_fan_config rpi5-fan-config
EOF
    
    print_success "Bash completion installed"
}

check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    # whiptail is part of newt package and should be installed by default on Raspberry Pi OS
    if ! command -v whiptail > /dev/null 2>&1; then
        missing_deps+=("whiptail")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_info "Installing missing dependencies: ${missing_deps[*]}"
        apt-get update -qq
        apt-get install -y "${missing_deps[@]}"
        print_success "Dependencies installed"
    else
        print_success "All dependencies satisfied"
    fi
}

main() {
    print_header
    check_root
    
    echo "This will install rpi5-fan-config system-wide."
    echo ""
    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    echo ""
    check_dependencies
    install_script
    install_man_page
    install_bash_completion
    create_desktop_entry
    
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "You can now run: sudo rpi5-fan-config"
    print_info "View the manual with: man rpi5-fan-config"
    echo ""
}

main
