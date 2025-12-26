# Example Configurations

This directory contains example fan control configurations for different use cases.

## Available Presets

### 1. Balanced (Recommended)
**File:** `balanced-preset.txt`  
**Best for:** General use, everyday computing

Good balance between cooling performance and noise levels. Suitable for most users.

- 40°C → ~30% fan speed
- 55°C → ~50% fan speed
- 67.5°C → ~70% fan speed
- 75°C → ~100% fan speed

### 2. Quiet
**File:** `quiet-preset.txt`  
**Best for:** Office environments, noise-sensitive situations

Prioritizes low noise levels while maintaining adequate cooling for normal workloads.

- 50°C → ~20% fan speed
- 60°C → ~30% fan speed
- 70°C → ~50% fan speed
- 80°C → ~80% fan speed

### 3. Performance
**File:** `performance-preset.txt`  
**Best for:** Heavy workloads, overclocking, 24/7 operation

Maximum cooling with earlier fan activation. More audible but keeps temperatures lower.

- 30°C → ~50% fan speed
- 50°C → ~70% fan speed
- 65°C → ~90% fan speed
- 70°C → ~100% fan speed

### 4. Silent
**File:** `silent-preset.txt`  
**Best for:** Light workloads, media centers, bedroom setups

Minimal fan activity for very quiet operation. Only suitable for light workloads.

- 55°C → ~20% fan speed
- 65°C → ~30% fan speed
- 75°C → ~50% fan speed
- 85°C → ~80% fan speed

### 5. Custom Template
**File:** `custom-template.txt`  
**Best for:** Creating your own configuration

Template with detailed comments for creating custom fan curves tailored to your needs.

## How to Use

### Option 1: Using the Configuration Tool (Recommended)
Simply run the tool and select a preset from the menu:
```bash
sudo rpi5-fan-config
```

### Option 2: Manual Application
Copy the desired configuration to your config.txt:

```bash
# Backup current config
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup

# Open config file
sudo nano /boot/firmware/config.txt

# Add the configuration from one of the example files after [all]
# Save and exit (Ctrl+X, then Y, then Enter)

# Reboot to apply
sudo reboot
```

## Choosing the Right Preset

Consider these factors:

- **Ambient temperature:** Hotter environments may need Performance preset
- **Workload:** CPU-intensive tasks benefit from Performance preset
- **Noise tolerance:** Use Quiet or Silent if noise is a concern
- **Case ventilation:** Poor ventilation may require Performance preset
- **Overclocking:** Always use Performance preset when overclocked

## Temperature Guidelines

Normal operating temperatures for Raspberry Pi 5:

- **Idle:** 40-50°C
- **Light use:** 50-60°C
- **Heavy use:** 60-75°C
- **Thermal throttling starts:** 80°C

The CPU will throttle at 80°C to protect itself, so aim to keep temperatures below this threshold under load.

## Customizing Configurations

To create your own configuration:

1. Start with the `custom-template.txt`
2. Adjust temperatures based on your typical usage
3. Set fan speeds to balance cooling and noise
4. Test and monitor temperatures
5. Fine-tune as needed

Remember: Fan speed / 2.5 ≈ percentage speed
