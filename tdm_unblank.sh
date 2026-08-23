#!/bin/bash
# unblank kernel framebuffer first (must precede VT poke on some drivers)
for fb_blank in /sys/class/graphics/fb*/blank; do
    if [[ -f "$fb_blank" ]]; then
        echo 0 > "$fb_blank" 2>/dev/null || true
    fi
done

for tty in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6 /dev/console; do
    if [[ -e "$tty" ]]; then
        setterm --blank poke --term linux < "$tty" > /dev/null 2>&1 || setterm --blank poke < "$tty" > /dev/null 2>&1 || true
        setterm --powersave off --term linux < "$tty" > /dev/null 2>&1 || setterm --powersave off < "$tty" > /dev/null 2>&1 || true
        setterm --blank 0 --term linux < "$tty" > /dev/null 2>&1 || setterm --blank 0 < "$tty" > /dev/null 2>&1 || true
    fi
done
setterm --blank poke --term linux 2>/dev/null || setterm --blank poke 2>/dev/null || true
setterm --powersave off --term linux 2>/dev/null || setterm --powersave off 2>/dev/null || true
setterm --blank 0 --term linux 2>/dev/null || setterm --blank 0 2>/dev/null || true
# re-assert fb unblank (some setterm implementations reset it)
for fb_blank in /sys/class/graphics/fb*/blank; do
    if [[ -f "$fb_blank" ]]; then
        echo 0 > "$fb_blank" 2>/dev/null || true
    fi
done