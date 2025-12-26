# Raspberry Pi 5 Fan Control Configuration Tool

A user-friendly configuration tool for managing PWM fan control on Raspberry Pi 5, featuring an intuitive menu interface similar to `raspi-config`.

## Features

- 🎯 **Interactive Whiptail Menu** - Professional GUI-style interface like raspi-config
- 🔧 **Multiple Presets** - Quiet, Balanced, Performance, and Silent profiles
- ⚙️ **Custom Configuration** - Create your own temperature/speed curves with guided dialogs
- 💾 **Automatic Backups** - Safely backs up your config before changes
- 🌡️ **Live Temperature Display** - Shows current CPU temperature in status
- 🔄 **Easy Restore** - Restore previous configurations from backup
- ✨ **No External Dependencies** - Uses built-in whiptail (pre-installed on Raspberry Pi OS)

## Requirements

- Raspberry Pi 5
- Raspberry Pi OS (or compatible Linux distribution)
- Root access (sudo)
- whiptail (pre-installed on Raspberry Pi OS)

## Installation

### Quick Install

```bash
chmod +x install.sh
sudo ./install.sh
```

### Manual Installation

```bash
# Make the script executable
chmod +x rpi5-fan-config.sh

# Run the configuration tool
sudo ./rpi5-fan-config.sh
```

## Usage

Simply run the script with sudo:

```bash
sudo rpi5-fan-config
```

Or if not installed system-wide:

```bash
sudo ./rpi5-fan-config.sh
```

### Menu Options

The tool provides a professional whiptail-based interface similar to raspi-config:

1. **View current configuration** - Display active fan settings with current CPU temperature
2. **Apply preset configuration** - Opens submenu with preset options:
   - QUIET preset
   - BALANCED preset (recommended)
   - PERFORMANCE preset
   - SILENT preset
3. **Custom configuration** - Step-by-step dialog boxes to define your own thresholds
4. **Remove fan configuration** - Reset to system defaults
5. **Restore from backup** - Restore previous configuration
6. **Monitor temperature** - Temperature monitoring and logging:
   - Live view - Real-time temperature display
   - Start logging: 10 minutes
   - Start logging: 1 hour
   - Start logging: Continuous
   - CPU stress test - Test fan response under load
7. **About** - Information about this tool

All options include confirmation dialogs and automatic reboot prompts when needed.

## Fan Speed Configuration

### Understanding PWM Values

The Raspberry Pi 5 uses PWM (Pulse Width Modulation) values from **0 to 255** to control fan speed.

As a general rule of thumb, the raw value can be divided by **2.5** to approximate the fan speed in percent:

$$
\mathrm{Fan\ Speed\ (\%)} \approx \frac{\mathrm{Raw\ Value}}{2.5}
$$

### Fan Speed Reference

| Raw Value | Approx. Fan Speed | Noise Level |
|-----------|-------------------|-------------|
| 50        | ~20%              | Very quiet  |
| 75        | ~30%              | Quiet       |
| 125       | ~50%              | Moderate    |
| 175       | ~70%              | Audible     |
| 200       | ~80%              | Clearly audible |
| 255       | ~100%             | Maximum noise |

### Temperature Values

Temperatures are specified in **millidegrees Celsius**:
- `30000` = 30°C
- `60000` = 60°C
- `75000` = 75°C

### Hysteresis

Hysteresis prevents rapid fan speed changes near temperature thresholds. A value of `5000` (5°C) means the temperature must drop 5°C below the threshold before the fan slows down.

## Configuration Presets

### 🔇 QUIET Preset
Best for: Office environments, noise-sensitive situations

| Temperature | Fan Speed | % Speed |
|-------------|-----------|---------|
| 50°C        | 50        | ~20%    |
| 60°C        | 75        | ~30%    |
| 70°C        | 125       | ~50%    |
| 80°C        | 200       | ~80%    |

### ⚖️ BALANCED Preset (Recommended)
Best for: General use, everyday computing

| Temperature | Fan Speed | % Speed |
|-------------|-----------|---------|
| 40°C        | 75        | ~30%    |
| 55°C        | 125       | ~50%    |
| 67.5°C      | 175       | ~70%    |
| 75°C        | 250       | ~100%   |

### 🚀 PERFORMANCE Preset
Best for: Heavy workloads, overclocking, maximum cooling

| Temperature | Fan Speed | % Speed |
|-------------|-----------|---------|
| 30°C        | 125       | ~50%    |
| 50°C        | 175       | ~70%    |
| 65°C        | 225       | ~90%    |
| 70°C        | 255       | ~100%   |

### 🤫 SILENT Preset
Best for: Light workloads, media centers, minimal cooling needs

| Temperature | Fan Speed | % Speed |
|-------------|-----------|---------|
| 55°C        | 50        | ~20%    |
| 65°C        | 75        | ~30%    |
| 75°C        | 125       | ~50%    |
| 85°C        | 200       | ~80%    |

## How It Works

The tool modifies `/boot/firmware/config.txt` to add fan control parameters. The configuration is applied at boot time by the Raspberry Pi firmware.

Example configuration in `config.txt`:

```ini
[all]

# >>> rpi5-fan-config START >>>
# Fan Control Configuration (added by rpi5-fan-config)
# Temperature values in millidegrees Celsius (30000 = 30°C)
# Speed values: 0-255 PWM scale (divide by 2.5 for approximate %)
dtparam=fan_temp0=40000
dtparam=fan_temp0_hyst=5000
dtparam=fan_temp0_speed=75

dtparam=fan_temp1=55000
dtparam=fan_temp1_hyst=5000
dtparam=fan_temp1_speed=125

dtparam=fan_temp2=67500
dtparam=fan_temp2_hyst=5000
dtparam=fan_temp2_speed=175

dtparam=fan_temp3=75000
dtparam=fan_temp3_hyst=5000
dtparam=fan_temp3_speed=250
# <<< rpi5-fan-config END <<<
```

## Safety Features

- ✅ **Automatic backup** - Creates backup before any changes
- ✅ **Restore capability** - Easily revert to previous configuration
- ✅ **Root check** - Prevents accidental execution without sudo
- ✅ **Model verification** - Warns if not running on Raspberry Pi 5
- ✅ **Configuration validation** - Ensures [all] section exists

## Troubleshooting

### Fan not responding to configuration

1. Verify the configuration was added to `config.txt`:
   ```bash
   sudo cat /boot/firmware/config.txt | grep fan_temp
   ```

2. Ensure you rebooted after making changes

3. Check that your fan is properly connected to the fan header

### Configuration file not found

If `/boot/firmware/config.txt` doesn't exist, your system might use `/boot/config.txt`:

```bash
# Check which file exists
ls -la /boot/firmware/config.txt
ls -la /boot/config.txt
```

Modify the `CONFIG_FILE` variable in the script if needed.

### Permission denied

Always run the script with `sudo`:
```bash
sudo ./rpi5-fan-config.sh
```

## Manual Configuration

If you prefer to edit the configuration manually:

```bash
# Backup the current configuration
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup

# Edit the configuration file
sudo nano /boot/firmware/config.txt

# Add your fan configuration after [all]
# Save and reboot
sudo reboot
```

## Monitoring Fan Speed

You can monitor your CPU temperature in real-time:

```bash
# Show current temperature
watch -n 1 'vcgencmd measure_temp'

# Or using thermal zone
watch -n 1 'cat /sys/class/thermal/thermal_zone0/temp | awk "{print \$1/1000\"°C\"}"'
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Based on official Raspberry Pi 5 documentation
- Inspired by `raspi-config` tool
- PWM fan control implementation from Raspberry Pi firmware

## Disclaimer

This tool modifies system configuration files. While it includes safety features and automatic backups, use at your own risk. Always ensure you have a way to access your Pi (keyboard, monitor) in case of issues.

---

**Made for Raspberry Pi 5** 🍓
