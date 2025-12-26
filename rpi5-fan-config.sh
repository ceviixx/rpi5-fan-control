#!/bin/bash

###############################################################################
# Raspberry Pi 5 Fan Control Configuration Tool
# 
# This script provides an interactive interface to configure the PWM fan
# control parameters in /boot/firmware/config.txt
#
# Fan speed values range from 0 to 255 (PWM scale)
# Approximate fan speed in % can be calculated: Raw Value / 2.5
###############################################################################

CONFIG_FILE="/boot/firmware/config.txt"
BACKUP_FILE="/boot/firmware/config.txt.backup"
LOG_DIR="/var/log/rpi5-fan"

# Terminal dimensions for whiptail
TERM_HEIGHT=20
TERM_WIDTH=78

# Color codes for terminal output (fallback)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

# Determine which dialog tool to use
if command -v whiptail > /dev/null 2>&1; then
    DIALOG_TOOL="whiptail"
elif command -v dialog > /dev/null 2>&1; then
    DIALOG_TOOL="dialog"
else
    echo "Error: Neither whiptail nor dialog found. Please install whiptail."
    exit 1
fi

msgbox() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --msgbox "$2" $TERM_HEIGHT $TERM_WIDTH
    else
        dialog --title "$1" --msgbox "$2" $TERM_HEIGHT $TERM_WIDTH
    fi
}

yesno() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --yesno "$2" $TERM_HEIGHT $TERM_WIDTH
    else
        dialog --title "$1" --yesno "$2" $TERM_HEIGHT $TERM_WIDTH
    fi
}

inputbox() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --inputbox "$2" $TERM_HEIGHT $TERM_WIDTH "$3" 3>&1 1>&2 2>&3
    else
        dialog --title "$1" --inputbox "$2" $TERM_HEIGHT $TERM_WIDTH "$3" 3>&1 1>&2 2>&3
    fi
}

menu() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --menu "$2" $TERM_HEIGHT $TERM_WIDTH $(($# - 2)) --ok-button "Select" --cancel-button "Finish" "${@:3}" 3>&1 1>&2 2>&3
    else
        dialog --title "$1" --menu "$2" $TERM_HEIGHT $TERM_WIDTH $(($# - 2)) --ok-label "Select" --cancel-label "Finish" "${@:3}" 3>&1 1>&2 2>&3
    fi
}

submenu() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --menu "$2" $TERM_HEIGHT $TERM_WIDTH $(($# - 2)) --ok-button "Select" --cancel-button "Back" "${@:3}" 3>&1 1>&2 2>&3
    else
        dialog --title "$1" --menu "$2" $TERM_HEIGHT $TERM_WIDTH $(($# - 2)) --ok-label "Select" --cancel-label "Back" "${@:3}" 3>&1 1>&2 2>&3
    fi
}

infobox() {
    if [ "$DIALOG_TOOL" = "whiptail" ]; then
        whiptail --title "$1" --infobox "$2" 8 $TERM_WIDTH
    else
        dialog --title "$1" --infobox "$2" 8 $TERM_WIDTH
    fi
    sleep 2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

###############################################################################
# Configuration Validation
###############################################################################

validate_config() {
    local t0=$1 s0=$2 t1=$3 s1=$4 t2=$5 s2=$6 t3=$7 s3=$8 h=$9
    
    # Check if all values are numeric
    if ! [[ "$t0" =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ "$t1" =~ ^[0-9]+\.?[0-9]*$ ]] || \
       ! [[ "$t2" =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ "$t3" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        return 1
    fi
    
    if ! [[ "$s0" =~ ^[0-9]+$ ]] || ! [[ "$s1" =~ ^[0-9]+$ ]] || \
       ! [[ "$s2" =~ ^[0-9]+$ ]] || ! [[ "$s3" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if ! [[ "$h" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        return 1
    fi
    
    # Check temperature ranges (0-100°C)
    if (( $(awk "BEGIN {print ($t0 < 0 || $t0 > 100)}") )) || \
       (( $(awk "BEGIN {print ($t1 < 0 || $t1 > 100)}") )) || \
       (( $(awk "BEGIN {print ($t2 < 0 || $t2 > 100)}") )) || \
       (( $(awk "BEGIN {print ($t3 < 0 || $t3 > 100)}") )); then
        return 1
    fi
    
    # Check temperatures are increasing
    if (( $(awk "BEGIN {print ($t0 >= $t1 || $t1 >= $t2 || $t2 >= $t3)}") )); then
        return 1
    fi
    
    # Check fan speed ranges (0-255)
    if (( s0 < 0 || s0 > 255 )) || (( s1 < 0 || s1 > 255 )) || \
       (( s2 < 0 || s2 > 255 )) || (( s3 < 0 || s3 > 255 )); then
        return 1
    fi
    
    # Check hysteresis range (0-20°C)
    if (( $(awk "BEGIN {print ($h < 0 || $h > 20)}") )); then
        return 1
    fi
    
    return 0
}

###############################################################################
# System Checks
###############################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_rpi5() {
    if [ ! -f "/proc/device-tree/model" ]; then
        yesno "Warning" "Cannot determine Raspberry Pi model.\n\nContinue anyway?" || exit 1
        return
    fi
    
    model=$(tr -d '\0' < /proc/device-tree/model)
    if [[ ! "$model" =~ "Raspberry Pi 5" ]]; then
        yesno "Warning" "This tool is designed for Raspberry Pi 5.\nDetected: $model\n\nContinue anyway?" || exit 1
    fi
}

backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        infobox "Backup" "Configuration backup created"
    fi
}

remove_existing_fan_config() {
    # First try to remove the entire fan configuration block between markers
    sed -i '/^# >>> rpi5-fan-config START >>>/,/^# <<< rpi5-fan-config END <<</d' "$CONFIG_FILE"
    
    # Fallback: Remove individual lines (for manual configurations or old versions)
    sed -i '/^dtparam=fan_temp[0-3]=/d' "$CONFIG_FILE"
    sed -i '/^dtparam=fan_temp[0-3]_hyst=/d' "$CONFIG_FILE"
    sed -i '/^dtparam=fan_temp[0-3]_speed=/d' "$CONFIG_FILE"
    sed -i '/^#dtparam=fan_temp[0-3]/d' "$CONFIG_FILE"
    
    # Remove old comment blocks if they exist
    sed -i '/^# Fan Control Configuration (added by rpi5-fan-config)/d' "$CONFIG_FILE"
    sed -i '/^# Temperature values in millidegrees Celsius/d' "$CONFIG_FILE"
    sed -i '/^# Speed values: 0-255 PWM scale/d' "$CONFIG_FILE"
}

ensure_all_section() {
    if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "[all]" >> "$CONFIG_FILE"
    fi
}

add_fan_config() {
    local temp0=$1
    local speed0=$2
    local temp1=$3
    local speed1=$4
    local temp2=$5
    local speed2=$6
    local temp3=$7
    local speed3=$8
    local hyst=${9:-5000}
    
    ensure_all_section
    
    # Add configuration after [all] section
    cat >> "$CONFIG_FILE" << EOF

# >>> rpi5-fan-config START >>>
# Fan Control Configuration (added by rpi5-fan-config)
# Temperature values in millidegrees Celsius (30000 = 30°C)
# Speed values: 0-255 PWM scale (divide by 2.5 for approximate %)
dtparam=fan_temp0=$temp0
dtparam=fan_temp0_hyst=$hyst
dtparam=fan_temp0_speed=$speed0

dtparam=fan_temp1=$temp1
dtparam=fan_temp1_hyst=$hyst
dtparam=fan_temp1_speed=$speed1

dtparam=fan_temp2=$temp2
dtparam=fan_temp2_hyst=$hyst
dtparam=fan_temp2_speed=$speed2

dtparam=fan_temp3=$temp3
dtparam=fan_temp3_hyst=$hyst
dtparam=fan_temp3_speed=$speed3
# <<< rpi5-fan-config END <<<
EOF
    
    infobox "Success" "Fan configuration has been applied"
}

show_current_config() {
    local config_text=""
    local temp_info=""
    
    # Get current temperature
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp_c=$(awk "BEGIN {printf \"%.1f\", $temp / 1000}")
        temp_info="Current CPU Temperature: ${temp_c}°C"
    fi
    
    if grep -q "dtparam=fan_temp" "$CONFIG_FILE"; then
        # Parse configuration using sed for precise extraction
        local temp0=$(sed -n 's/^dtparam=fan_temp0=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local speed0=$(sed -n 's/^dtparam=fan_temp0_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local temp1=$(sed -n 's/^dtparam=fan_temp1=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local speed1=$(sed -n 's/^dtparam=fan_temp1_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local temp2=$(sed -n 's/^dtparam=fan_temp2=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local speed2=$(sed -n 's/^dtparam=fan_temp2_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local temp3=$(sed -n 's/^dtparam=fan_temp3=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local speed3=$(sed -n 's/^dtparam=fan_temp3_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        local hyst=$(sed -n 's/^dtparam=fan_temp0_hyst=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
        
        # Check if values are valid
        if [[ -z "$temp0" || -z "$speed0" ]]; then
            config_text=$(grep "dtparam=fan_temp" "$CONFIG_FILE" | grep -v "^#")
            msgbox "Current Fan Configuration" "${temp_info}\n\n${config_text}"
            return
        fi
        
        # Detect preset mode
        local preset_name="CUSTOM"
        if [ "$temp0" = "50000" ] && [ "$speed0" = "50" ] && [ "$temp1" = "60000" ] && [ "$speed1" = "75" ] && \
           [ "$temp2" = "70000" ] && [ "$speed2" = "125" ] && [ "$temp3" = "80000" ] && [ "$speed3" = "200" ]; then
            preset_name="QUIET"
        elif [ "$temp0" = "40000" ] && [ "$speed0" = "75" ] && [ "$temp1" = "55000" ] && [ "$speed1" = "125" ] && \
             [ "$temp2" = "67500" ] && [ "$speed2" = "175" ] && [ "$temp3" = "75000" ] && [ "$speed3" = "250" ]; then
            preset_name="BALANCED"
        elif [ "$temp0" = "30000" ] && [ "$speed0" = "125" ] && [ "$temp1" = "50000" ] && [ "$speed1" = "175" ] && \
             [ "$temp2" = "65000" ] && [ "$speed2" = "225" ] && [ "$temp3" = "70000" ] && [ "$speed3" = "255" ]; then
            preset_name="PERFORMANCE"
        elif [ "$temp0" = "55000" ] && [ "$speed0" = "50" ] && [ "$temp1" = "65000" ] && [ "$speed1" = "75" ] && \
             [ "$temp2" = "75000" ] && [ "$speed2" = "125" ] && [ "$temp3" = "85000" ] && [ "$speed3" = "200" ]; then
            preset_name="SILENT"
        fi
        
        # Convert to readable format
        local temp0_c=$(awk "BEGIN {printf \"%.1f\", $temp0/1000}")
        local speed0_pct=$(awk "BEGIN {printf \"%.0f\", $speed0/2.5}")
        local temp1_c=$(awk "BEGIN {printf \"%.1f\", $temp1/1000}")
        local speed1_pct=$(awk "BEGIN {printf \"%.0f\", $speed1/2.5}")
        local temp2_c=$(awk "BEGIN {printf \"%.1f\", $temp2/1000}")
        local speed2_pct=$(awk "BEGIN {printf \"%.0f\", $speed2/2.5}")
        local temp3_c=$(awk "BEGIN {printf \"%.1f\", $temp3/1000}")
        local speed3_pct=$(awk "BEGIN {printf \"%.0f\", $speed3/2.5}")
        local hyst_c=$(awk "BEGIN {printf \"%.1f\", $hyst/1000}")
        
        # Simple list format - no table needed
        config_text="Mode: ${preset_name}\n\nLevel 1:  ${temp0_c}°C  →  PWM ${speed0} (~${speed0_pct}%)
Level 2:  ${temp1_c}°C  →  PWM ${speed1} (~${speed1_pct}%)
Level 3:  ${temp2_c}°C  →  PWM ${speed2} (~${speed2_pct}%)
Level 4:  ${temp3_c}°C  →  PWM ${speed3} (~${speed3_pct}%)

Hysteresis: ${hyst_c}°C
(Fan slows down when temp drops ${hyst_c}°C below threshold)"
    else
        config_text="No fan configuration found in config.txt"
    fi
    
    msgbox "Current Fan Configuration" "${temp_info}\n\n${config_text}"
}

###############################################################################
# Temperature Monitoring Functions
###############################################################################

get_cpu_temp() {
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $(awk "BEGIN {printf \"%.1f\", $temp / 1000}")
    else
        echo "N/A"
    fi
}

get_current_pwm() {
    # Try to read current PWM value from fan control
    # This may not be directly readable, so we estimate based on config
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    local temp_c=$(awk "BEGIN {printf \"%.0f\", $temp / 1000}")
    
    # Parse thresholds from config
    local temp0=$(sed -n 's/^dtparam=fan_temp0=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local speed0=$(sed -n 's/^dtparam=fan_temp0_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local temp1=$(sed -n 's/^dtparam=fan_temp1=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local speed1=$(sed -n 's/^dtparam=fan_temp1_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local temp2=$(sed -n 's/^dtparam=fan_temp2=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local speed2=$(sed -n 's/^dtparam=fan_temp2_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local temp3=$(sed -n 's/^dtparam=fan_temp3=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    local speed3=$(sed -n 's/^dtparam=fan_temp3_speed=\([0-9]*\)$/\1/p' "$CONFIG_FILE")
    
    # Default if no config
    if [[ -z "$temp0" ]]; then
        echo "0,0"
        return
    fi
    
    # Convert to celsius for comparison
    local t0=$(awk "BEGIN {printf \"%.0f\", $temp0 / 1000}")
    local t1=$(awk "BEGIN {printf \"%.0f\", $temp1 / 1000}")
    local t2=$(awk "BEGIN {printf \"%.0f\", $temp2 / 1000}")
    local t3=$(awk "BEGIN {printf \"%.0f\", $temp3 / 1000}")
    
    # Determine active threshold
    local pwm=0
    local threshold=0
    if (( temp_c >= t3 )); then
        pwm=$speed3
        threshold=4
    elif (( temp_c >= t2 )); then
        pwm=$speed2
        threshold=3
    elif (( temp_c >= t1 )); then
        pwm=$speed1
        threshold=2
    elif (( temp_c >= t0 )); then
        pwm=$speed0
        threshold=1
    fi
    
    echo "$pwm,$threshold"
}

monitor_live() {
    clear
    echo "=== Raspberry Pi 5 Fan Monitoring ==="
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Trap Ctrl+C
    trap 'echo -e "\n\nMonitoring stopped."; return' INT
    
    while true; do
        local temp=$(get_cpu_temp)
        local pwm_info=$(get_current_pwm)
        local pwm=$(echo $pwm_info | cut -d',' -f1)
        local threshold=$(echo $pwm_info | cut -d',' -f2)
        local pwm_pct=$(awk "BEGIN {printf \"%.0f\", $pwm / 2.5}")
        
        # Color coding
        local color=$GREEN
        if (( $(awk "BEGIN {print ($temp >= 75)}") )); then
            color=$RED
        elif (( $(awk "BEGIN {print ($temp >= 60)}") )); then
            color=$YELLOW
        fi
        
        # Clear previous line and print new data
        echo -ne "\r\033[K"
        echo -ne "${color}Temperature: ${temp}°C${NC} | PWM: ${pwm} (~${pwm_pct}%) | Threshold: ${threshold}/4"
        
        sleep 2
    done
    
    trap - INT
}

monitor_logging() {
    local duration=$1  # in minutes, 0 = continuous
    local logfile="$LOG_DIR/monitoring-$(date +%Y%m%d-%H%M%S).csv"
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Write CSV header
    echo "timestamp,cpu_temp_c,fan_pwm,pwm_percent,active_threshold" > "$logfile"
    
    clear
    echo "=== Temperature Logging Mode ==="
    echo "Log file: $logfile"
    if [ $duration -eq 0 ]; then
        echo "Duration: Continuous (Press Ctrl+C to stop)"
    else
        echo "Duration: $duration minutes"
    fi
    echo ""
    echo "Logging started..."
    echo ""
    
    local start_time=$(date +%s)
    local end_time
    if [ $duration -gt 0 ]; then
        end_time=$((start_time + duration * 60))
    else
        end_time=0
    fi
    
    # Statistics tracking
    local min_temp=999
    local max_temp=0
    local sum_temp=0
    local min_pwm=999
    local max_pwm=0
    local sum_pwm=0
    local count=0
    local threshold_changes=0
    local last_threshold=0
    
    trap 'echo -e "\n\nLogging stopped by user."; show_monitoring_summary "$logfile" "$min_temp" "$max_temp" "$sum_temp" "$min_pwm" "$max_pwm" "$sum_pwm" "$count" "$threshold_changes"; return' INT
    
    while true; do
        local current_time=$(date +%s)
        
        # Check if duration expired
        if [ $end_time -gt 0 ] && [ $current_time -ge $end_time ]; then
            break
        fi
        
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local temp=$(get_cpu_temp)
        local pwm_info=$(get_current_pwm)
        local pwm=$(echo $pwm_info | cut -d',' -f1)
        local threshold=$(echo $pwm_info | cut -d',' -f2)
        local pwm_pct=$(awk "BEGIN {printf \"%.0f\", $pwm / 2.5}")
        
        # Write to CSV
        echo "$timestamp,$temp,$pwm,$pwm_pct,$threshold" >> "$logfile"
        
        # Update statistics
        count=$((count + 1))
        if (( $(awk "BEGIN {print ($temp < $min_temp)}") )); then min_temp=$temp; fi
        if (( $(awk "BEGIN {print ($temp > $max_temp)}") )); then max_temp=$temp; fi
        sum_temp=$(awk "BEGIN {printf \"%.1f\", $sum_temp + $temp}")
        
        if [ $pwm -lt $min_pwm ]; then min_pwm=$pwm; fi
        if [ $pwm -gt $max_pwm ]; then max_pwm=$pwm; fi
        sum_pwm=$((sum_pwm + pwm))
        
        if [ $threshold -ne $last_threshold ]; then
            threshold_changes=$((threshold_changes + 1))
            last_threshold=$threshold
        fi
        
        # Display current values
        echo -ne "\r\033[K"
        echo -ne "Current: ${temp}°C | PWM: ${pwm} (~${pwm_pct}%) | Threshold: ${threshold}/4 | Samples: ${count}"
        
        sleep 2
    done
    
    trap - INT
    
    echo ""
    echo ""
    show_monitoring_summary "$logfile" "$min_temp" "$max_temp" "$sum_temp" "$min_pwm" "$max_pwm" "$sum_pwm" "$count" "$threshold_changes"
}

show_monitoring_summary() {
    local logfile=$1
    local min_temp=$2
    local max_temp=$3
    local sum_temp=$4
    local min_pwm=$5
    local max_pwm=$6
    local sum_pwm=$7
    local count=$8
    local threshold_changes=$9
    
    local avg_temp=$(awk "BEGIN {printf \"%.1f\", $sum_temp / $count}")
    local avg_pwm=$(awk "BEGIN {printf \"%.0f\", $sum_pwm / $count}")
    local min_pwm_pct=$(awk "BEGIN {printf \"%.0f\", $min_pwm / 2.5}")
    local max_pwm_pct=$(awk "BEGIN {printf \"%.0f\", $max_pwm / 2.5}")
    local avg_pwm_pct=$(awk "BEGIN {printf \"%.0f\", $avg_pwm / 2.5}")
    
    local duration_sec=$((count * 2))
    local duration_min=$(awk "BEGIN {printf \"%.1f\", $duration_sec / 60}")
    
    msgbox "Monitoring Summary" "Duration: ${duration_min} minutes (${count} samples)\n\nTemperature:\n  Min: ${min_temp}°C | Max: ${max_temp}°C | Avg: ${avg_temp}°C\n\nFan Speed:\n  Min: PWM ${min_pwm} (~${min_pwm_pct}%)\n  Max: PWM ${max_pwm} (~${max_pwm_pct}%)\n  Avg: PWM ${avg_pwm} (~${avg_pwm_pct}%)\n\nThreshold Changes: ${threshold_changes}\n\nLog saved to:\n${logfile}"
}

run_stress_test() {
    if ! yesno "CPU Stress Test" "This will stress all CPU cores for 2 minutes to test your fan configuration.\n\nThe test will:\n- Load all CPU cores with mathematical operations\n- Monitor temperature and fan response\n- Show which thresholds are activated\n- Display temperature curve\n\nNote: If your cooling is very effective, temperature may not rise significantly.\n\nContinue?"; then
        return
    fi
    
    # Run stress test in background and monitor
    clear
    echo "=== CPU Stress Test ==="
    echo "Starting built-in stress test on all CPU cores..."
    echo "Duration: 2 minutes (120 seconds)"
    echo "Press Ctrl+C to abort"
    echo ""
    
    # Get number of CPU cores
    local num_cores=$(nproc)
    
    # Start stress workers in background (one per CPU core)
    local stress_pids=()
    for ((core=0; core<num_cores; core++)); do
        (
            # Infinite loop doing intensive calculations
            while true; do
                # Calculate prime numbers and square roots
                awk 'BEGIN {
                    for (i=1; i<=10000; i++) {
                        sqrt(i * i * i);
                        for (j=2; j<i; j++) {
                            k = i % j;
                        }
                    }
                }' 2>/dev/null
            done
        ) &
        stress_pids+=($!)
    done
    
    # Monitoring variables
    local start_temp=$(get_cpu_temp)
    local max_temp=0
    local samples=0
    local threshold_log=""
    local last_threshold=0
    
    echo "Initial temperature: ${start_temp}°C"
    echo "Stressing ${num_cores} CPU cores..."
    echo ""
    echo "Time  | Temp   | PWM | %   | Threshold | Status"
    echo "------+--------+-----+-----+-----------+--------"
    
    trap 'for pid in "${stress_pids[@]}"; do kill $pid 2>/dev/null; done; wait 2>/dev/null; echo -e "\n\nTest aborted by user."; return' INT
    
    # Run for 60 iterations (2 minutes with 2-second intervals)
    for i in {1..60}; do
        local temp=$(get_cpu_temp)
        local pwm_info=$(get_current_pwm)
        local pwm=$(echo $pwm_info | cut -d',' -f1)
        local threshold=$(echo $pwm_info | cut -d',' -f2)
        local pwm_pct=$(awk "BEGIN {printf \"%.0f\", $pwm / 2.5}")
        
        # Track max temp
        if (( $(awk "BEGIN {print ($temp > $max_temp)}") )); then
            max_temp=$temp
        fi
        
        # Log threshold changes
        if [ $threshold -ne $last_threshold ]; then
            threshold_log="${threshold_log}\n  ${i}s: Switched to Threshold ${threshold} (Temp: ${temp}°C)"
            last_threshold=$threshold
        fi
        
        # Status indicator
        local status="OK"
        local color=$GREEN
        if (( $(awk "BEGIN {print ($temp >= 75)}") )); then
            status="HIGH"
            color=$RED
        elif (( $(awk "BEGIN {print ($temp >= 60)}") )); then
            status="WARM"
            color=$YELLOW
        fi
        
        # Only print every 5 seconds to reduce clutter, but always print threshold changes
        if [ $((i % 5)) -eq 0 ] || [ $threshold -ne $last_threshold ]; then
            printf "%4ds | ${color}%5.1f°C${NC} | %3d | %2d%% | Level %d/4    | %s\n" \
                $((i*2)) "$temp" "$pwm" "$pwm_pct" "$threshold" "$status"
        fi
        
        samples=$((samples + 1))
        sleep 2
    done
    
    trap - INT
    
    # Stop all stress workers
    for pid in "${stress_pids[@]}"; do
        kill $pid 2>/dev/null
    done
    wait 2>/dev/null
    
    echo ""
    echo "=== Test Complete ==="
    echo ""
    
    # Calculate stats
    local final_temp=$(get_cpu_temp)
    local temp_increase=$(awk "BEGIN {printf \"%.1f\", $final_temp - $start_temp}")
    
    # Determine if test was effective
    local effectiveness_note=""
    if (( $(awk "BEGIN {print ($max_temp < 55)}") )); then
        effectiveness_note="\n\nNote: Peak temperature stayed below 55°C.\nYour cooling is very effective! Consider using a quieter preset (QUIET or SILENT) for better noise levels."
    fi
    
    # Summary
    local summary="Stress Test Summary\n\n"
    summary="${summary}Duration: ${samples} samples (${samples}x2 = $((samples*2)) seconds)\n\n"
    summary="${summary}Temperature:\n"
    summary="${summary}  Start: ${start_temp}°C\n"
    summary="${summary}  Peak: ${max_temp}°C\n"
    summary="${summary}  Final: ${final_temp}°C\n"
    summary="${summary}  Increase: +${temp_increase}°C\n\n"
    
    if [ -z "$threshold_log" ]; then
        summary="${summary}Threshold Changes: None\n"
        summary="${summary}(Temperature stayed within first threshold range)\n"
    else
        summary="${summary}Threshold Changes:${threshold_log}\n"
    fi
    
    summary="${summary}${effectiveness_note}"
    
    msgbox "Stress Test Complete" "$summary"
}

show_monitor_menu() {
    while true; do
        local choice
        choice=$(submenu "Temperature Monitoring" "Choose monitoring mode:" \
            "1" "Live view - Real-time temperature display" \
            "2" "Log 10 minutes - Record data for analysis" \
            "3" "Log 1 hour - Extended monitoring session" \
            "4" "Log continuous - Until manually stopped" \
            "5" "CPU stress test - Test fan response under load")
        
        case $choice in
            1)
                monitor_live
                ;;
            2)
                monitor_logging 10
                ;;
            3)
                monitor_logging 60
                ;;
            4)
                monitor_logging 0
                ;;
            5)
                run_stress_test
                ;;
            *)
                # Back button pressed
                break
                ;;
        esac
    done
}

###############################################################################
# Configuration Presets
###############################################################################

apply_preset() {
    local preset_name=$1
    local temp0=$2
    local speed0=$3
    local temp1=$4
    local speed1=$5
    local temp2=$6
    local speed2=$7
    local temp3=$8
    local speed3=$9
    
    backup_config
    remove_existing_fan_config
    add_fan_config $temp0 $speed0 $temp1 $speed1 $temp2 $speed2 $temp3 $speed3
    
    if yesno "Reboot Required" "The $preset_name preset has been applied.\n\nA reboot is required for changes to take effect.\n\nReboot now?"; then
        reboot
    fi
}

preset_quiet() {
    apply_preset "QUIET" 50000 50 60000 75 70000 125 80000 200
}

preset_balanced() {
    apply_preset "BALANCED" 40000 75 55000 125 67500 175 75000 250
}

preset_performance() {
    apply_preset "PERFORMANCE" 30000 125 50000 175 65000 225 70000 255
}

preset_silent() {
    apply_preset "SILENT" 55000 50 65000 75 75000 125 85000 200
}

custom_config() {
    msgbox "Custom Configuration" "You will configure 4 temperature thresholds and their fan speeds.\n\nTemperature: in °C\nSpeed: 0-255 (divide by 2.5 for ~%)\n\nPress OK to continue."
    
    # Temperature 1
    temp0=$(inputbox "Temperature Threshold 1" "Enter temperature for first threshold (°C):" "40")
    [ $? -ne 0 ] && return
    temp0=${temp0:-40}
    
    speed0=$(inputbox "Fan Speed 1" "Enter fan speed for ${temp0}°C (0-255):\n\nReference: 75 = ~30%, 125 = ~50%, 175 = ~70%" "75")
    [ $? -ne 0 ] && return
    speed0=${speed0:-75}
    
    # Temperature 2
    temp1=$(inputbox "Temperature Threshold 2" "Enter temperature for second threshold (°C):" "55")
    [ $? -ne 0 ] && return
    temp1=${temp1:-55}
    
    speed1=$(inputbox "Fan Speed 2" "Enter fan speed for ${temp1}°C (0-255):\n\nReference: 75 = ~30%, 125 = ~50%, 175 = ~70%" "125")
    [ $? -ne 0 ] && return
    speed1=${speed1:-125}
    
    # Temperature 3
    temp2=$(inputbox "Temperature Threshold 3" "Enter temperature for third threshold (°C):" "67.5")
    [ $? -ne 0 ] && return
    temp2=${temp2:-67.5}
    
    speed2=$(inputbox "Fan Speed 3" "Enter fan speed for ${temp2}°C (0-255):\n\nReference: 75 = ~30%, 125 = ~50%, 175 = ~70%" "175")
    [ $? -ne 0 ] && return
    speed2=${speed2:-175}
    
    # Temperature 4
    temp3=$(inputbox "Temperature Threshold 4" "Enter temperature for fourth threshold (°C):" "75")
    [ $? -ne 0 ] && return
    temp3=${temp3:-75}
    
    speed3=$(inputbox "Fan Speed 4" "Enter fan speed for ${temp3}°C (0-255):\n\nReference: 75 = ~30%, 125 = ~50%, 200 = ~80%, 255 = ~100%" "250")
    [ $? -ne 0 ] && return
    speed3=${speed3:-250}
    
    # Hysteresis
    hyst=$(inputbox "Hysteresis" "Enter hysteresis value (°C):\n\nThis prevents rapid fan speed changes.\nRecommended: 5" "5")
    [ $? -ne 0 ] && return
    hyst=${hyst:-5}
    
    # Validate configuration
    if ! validate_config "$temp0" "$speed0" "$temp1" "$speed1" "$temp2" "$speed2" "$temp3" "$speed3" "$hyst"; then
        msgbox "Invalid Configuration" "Configuration validation failed.\n\nPlease check:\n- Temperatures must increase (temp1 < temp2 < temp3 < temp4)\n- Temperatures between 0-100°C\n- Fan speeds between 0-255\n- Hysteresis between 0-20°C"
        return
    fi
    
    # Convert temperatures to millidegrees
    temp0_m=$(awk "BEGIN {printf \"%.0f\", $temp0 * 1000}")
    temp1_m=$(awk "BEGIN {printf \"%.0f\", $temp1 * 1000}")
    temp2_m=$(awk "BEGIN {printf \"%.0f\", $temp2 * 1000}")
    temp3_m=$(awk "BEGIN {printf \"%.0f\", $temp3 * 1000}")
    hyst_m=$(awk "BEGIN {printf \"%.0f\", $hyst * 1000}")
    
    backup_config
    remove_existing_fan_config
    add_fan_config $temp0_m $speed0 $temp1_m $speed1 $temp2_m $speed2 $temp3_m $speed3 $hyst_m
    
    if yesno "Reboot Required" "Custom configuration has been applied.\n\nA reboot is required for changes to take effect.\n\nReboot now?"; then
        reboot
    fi
}

###############################################################################
# Preset Selection Menu
###############################################################################

show_preset_menu() {
    while true; do
        local choice
        choice=$(submenu "Select Fan Preset" "Choose a fan control preset:" \
            "1" "QUIET - Minimal noise, moderate cooling" \
            "2" "BALANCED - Recommended for most users" \
            "3" "PERFORMANCE - Maximum cooling, more noise" \
            "4" "SILENT - Very quiet, light workloads only")
        
        case $choice in
            1) 
                if yesno "QUIET Preset" "This preset provides minimal noise with moderate cooling.\n\nConfiguration:\n  50°C → Speed 50 (~20%)\n  60°C → Speed 75 (~30%)\n  70°C → Speed 125 (~50%)\n  80°C → Speed 200 (~80%)\n\nApply this preset?"; then
                    preset_quiet
                fi
                ;;
            2)
                if yesno "BALANCED Preset" "This preset provides a good balance of cooling and noise.\nRecommended for most users.\n\nConfiguration:\n  40°C → Speed 75 (~30%)\n  55°C → Speed 125 (~50%)\n  67.5°C → Speed 175 (~70%)\n  75°C → Speed 250 (~100%)\n\nApply this preset?"; then
                    preset_balanced
                fi
                ;;
            3)
                if yesno "PERFORMANCE Preset" "This preset provides maximum cooling with more noise.\nGood for heavy workloads and overclocking.\n\nConfiguration:\n  30°C → Speed 125 (~50%)\n  50°C → Speed 175 (~70%)\n  65°C → Speed 225 (~90%)\n  70°C → Speed 255 (~100%)\n\nApply this preset?"; then
                    preset_performance
                fi
                ;;
            4)
                if yesno "SILENT Preset" "This preset provides very quiet operation.\nOnly suitable for light workloads.\n\nConfiguration:\n  55°C → Speed 50 (~20%)\n  65°C → Speed 75 (~30%)\n  75°C → Speed 125 (~50%)\n  85°C → Speed 200 (~80%)\n\nApply this preset?"; then
                    preset_silent
                fi
                ;;
            *)
                # Back button pressed or empty - return to main menu
                break
                ;;
        esac
    done
}

###############################################################################
# Main Menu
###############################################################################

show_about() {
    msgbox "About" "Raspberry Pi 5 Fan Control Configuration Tool\n\nA user-friendly tool for configuring PWM fan control on Raspberry Pi 5.\n\nGitHub: github.com/ceviixx/rpi5-fan-control\n\nLicense: MIT"
}

show_main_menu() {
    local choice
    choice=$(menu "Raspberry Pi 5 Fan Control" "Configure PWM fan control settings:" \
        "1" "View current configuration    Display active fan settings" \
        "2" "Apply preset configuration    Choose from predefined profiles" \
        "3" "Custom configuration          Define custom temperature/speed curves" \
        "4" "Remove fan configuration      Reset to system defaults" \
        "5" "Restore from backup           Restore previous configuration" \
        "6" "Monitor temperature           Live view and logging" \
        "7" "About                         Information about this tool")
    
    echo "$choice"
}

###############################################################################
# Main Program
###############################################################################

main() {
    check_root
    check_rpi5
    
    while true; do
        choice=$(show_main_menu)
        
        case $choice in
            "")
                # Finish button pressed in main menu - exit
                clear
                exit 0
                ;;
            1)
                show_current_config
                ;;
            2)
                show_preset_menu
                # Continue after preset menu returns
                ;;
            3)
                custom_config
                ;;
            4)
                if yesno "Remove Configuration" "This will remove all fan configuration settings.\n\nA reboot will be required.\n\nContinue?"; then
                    backup_config
                    remove_existing_fan_config
                    infobox "Configuration Removed" "Fan configuration has been removed"
                    if yesno "Reboot Required" "A reboot is required for changes to take effect.\n\nReboot now?"; then
                        reboot
                    fi
                fi
                ;;
            5)
                if [ -f "$BACKUP_FILE" ]; then
                    if yesno "Restore Backup" "This will restore the configuration from backup.\n\nA reboot will be required.\n\nContinue?"; then
                        cp "$BACKUP_FILE" "$CONFIG_FILE"
                        infobox "Backup Restored" "Configuration has been restored from backup"
                        if yesno "Reboot Required" "A reboot is required for changes to take effect.\n\nReboot now?"; then
                            reboot
                        fi
                    fi
                else
                    msgbox "Error" "No backup file found at:\n$BACKUP_FILE"
                fi
                ;;
            6)
                show_monitor_menu
                ;;
            7)
                show_about
                ;;
            *)
                # Unknown option - ignore and continue
                ;;
        esac
    done
}

# Run the main program
main
