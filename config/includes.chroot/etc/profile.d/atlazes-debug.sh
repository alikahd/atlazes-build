#!/bin/bash
# ATLAZES OS - Debug helper for live session
# يُشغَّل عند أول تسجيل دخول لتشخيص مشاكل العرض

# فقط في الجلسة الحية وفقط مرة واحدة
if [[ -f /run/live/medium/live/filesystem.squashfs ]] && \
   [[ ! -f /tmp/.atlazes-debug-done ]]; then
    touch /tmp/.atlazes-debug-done

    # تسجيل معلومات الجلسة
    {
        echo "=== ATLAZES OS Live Session Debug ==="
        echo "Date: $(date)"
        echo "Kernel: $(uname -r)"
        echo "Display: $DISPLAY"
        echo "GPU:"
        lspci | grep -i "vga\|display\|3d" 2>/dev/null || echo "  (lspci not available)"
        echo "Xorg log (last 20 lines):"
        tail -20 /var/log/Xorg.0.log 2>/dev/null || \
        tail -20 ~/.local/share/xorg/Xorg.0.log 2>/dev/null || \
        echo "  (no Xorg log)"
        echo "LightDM log (last 20 lines):"
        tail -20 /var/log/lightdm/lightdm.log 2>/dev/null || echo "  (no LightDM log)"
    } > /tmp/atlazes-session-debug.txt 2>&1

    # إذا كان هناك terminal متاح، اعرض رسالة
    if [[ -t 1 ]]; then
        echo ""
        echo "  ATLAZES OS - Live Session"
        echo "  Debug log: /tmp/atlazes-session-debug.txt"
        echo ""
    fi
fi
