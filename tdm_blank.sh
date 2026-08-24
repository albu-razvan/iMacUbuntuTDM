#!/bin/bash
# re-enable blanking briefly so force works (tdm_unblank sets blank 0)
for tty in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6 /dev/console; do
    if [[ -e "$tty" ]]; then
        setterm --blank 1 --term linux < "$tty" > /dev/null 2>&1 || true
    fi
done

# if the driver exposes backlight power control, ask it to power down too
for bl_power in /sys/class/backlight/*/bl_power; do
    if [[ -f "$bl_power" ]]; then
        echo 4 > "$bl_power" 2>/dev/null || echo 1 > "$bl_power" 2>/dev/null || true
    fi
done

# kernel framebuffer blank via sysfs (more reliable than VT blank alone on radeon DRM)
for fb_blank in /sys/class/graphics/fb*/blank; do
    if [[ -f "$fb_blank" ]]; then
        echo 1 > "$fb_blank" 2>/dev/null || echo 4 > "$fb_blank" 2>/dev/null || true
    fi
done

# force blank and clear all VTs + DPMS powerdown
for tty in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6 /dev/console; do
    if [[ -e "$tty" ]]; then
        setterm --blank force --term linux < "$tty" > /dev/null 2>&1 || setterm --blank force < "$tty" > /dev/null 2>&1 || true
        setterm --powersave powerdown --term linux < "$tty" > /dev/null 2>&1 || setterm --powersave powerdown < "$tty" > /dev/null 2>&1 || true
        setterm --clear --term linux < "$tty" > /dev/null 2>&1 || setterm --clear < "$tty" > /dev/null 2>&1 || true
        # also send reset/clear escape
        printf "\033c" > "$tty" 2>/dev/null || true
        clear < "$tty" > /dev/null 2>&1 || true
    fi
done
# also try on current tty without redirection
setterm --blank force --term linux 2>/dev/null || setterm --blank force 2>/dev/null || true
setterm --powersave powerdown --term linux 2>/dev/null || setterm --powersave powerdown 2>/dev/null || true
# re-assert fb blank after setterm (some drivers reset it)
for fb_blank in /sys/class/graphics/fb*/blank; do
    if [[ -f "$fb_blank" ]]; then
        echo 1 > "$fb_blank" 2>/dev/null || echo 4 > "$fb_blank" 2>/dev/null || true
    fi
done
