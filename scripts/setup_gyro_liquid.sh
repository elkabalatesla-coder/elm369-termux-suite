#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p ~/gyro_liquid_3d
cd ~/gyro_liquid_3d

cat << 'PYEOF' > ~/gyro_liquid_3d/gyro_liquid.py
import colorsys
import math
import os
import shutil
import subprocess
import sys
import time


def clamp(val, low, high):
    return max(low, min(high, val))


def rgb_to_hex(r, g, b):
    return f"#{int(clamp(r, 0, 255)):02X}{int(clamp(g, 0, 255)):02X}{int(clamp(b, 0, 255)):02X}"


def rgb_to_hsv_deg(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(
        clamp(r, 0, 255) / 255.0,
        clamp(g, 0, 255) / 255.0,
        clamp(b, 0, 255) / 255.0,
    )
    return round(h * 360.0, 1), round(s * 100.0, 1), round(v * 100.0, 1)


def rgb_to_hsl_deg(r, g, b):
    h, l, s = colorsys.rgb_to_hls(
        clamp(r, 0, 255) / 255.0,
        clamp(g, 0, 255) / 255.0,
        clamp(b, 0, 255) / 255.0,
    )
    return round(h * 360.0, 1), round(s * 100.0, 1), round(l * 100.0, 1)


def read_gyro_sample():
    """Attempts to read a single gyroscope sample via termux-sensor; falls back cleanly."""
    if shutil.which("termux-sensor"):
        try:
            proc = subprocess.run(
                ["termux-sensor", "-s", "gyroscope", "-n", "1"],
                capture_output=True,
                text=True,
                timeout=1.5,
            )
            if proc.returncode == 0 and proc.stdout.strip():
                # Look for three floats in output if JSON/text is returned
                import re
                nums = re.findall(r"[-+]?\d*\.\d+|\d+", proc.stdout)
                if len(nums) >= 3:
                    return float(nums[-3]), float(nums[-2]), float(nums[-1]), "termux-sensor"
        except Exception:
            pass
    t = time.time()
    return (
        math.sin(t * 1.4) * 1.8,
        math.cos(t * 1.1) * 1.8,
        math.sin(t * 0.7) * 1.2,
        "simulated-fallback",
    )


def render_frame(gx, gy, gz, source, phase):
    cols, rows = shutil.get_terminal_size((80, 24))
    grid_rows = max(8, rows - 9)
    grid_cols = max(20, min(cols - 2, 100))

    # Map gyroscope angular velocity into hue shift and energy
    hue_base = (phase * 25.0 + (gx * 35.0) + (gy * 25.0)) % 360.0
    energy = clamp(0.45 + (abs(gx) + abs(gy) + abs(gz)) * 0.15, 0.35, 1.0)

    r_f, g_f, b_f = colorsys.hsv_to_rgb(hue_base / 360.0, 0.88, energy)
    r, g, b = int(r_f * 255), int(g_f * 255), int(b_f * 255)
    hex_code = rgb_to_hex(r, g, b)
    hsv_vals = rgb_to_hsv_deg(r, g, b)
    hsl_vals = rgb_to_hsl_deg(r, g, b)

    liquid_chars = " .:-=+*#%@"
    lines = ["\033[H\033[?25l"]
    lines.append(
        f"GYRO 3D LIQUID MATRIX [{source}] | gx={gx:+.2f} gy={gy:+.2f} gz={gz:+.2f}"
    )
    lines.append(
        f"HEX: {hex_code} | RGB: ({r}, {g}, {b}) | HSV: {hsv_vals} | HSL: {hsl_vals}"
    )
    lines.append("-" * min(cols, 100))

    for y in range(grid_rows):
        ny = (y / max(1, grid_rows - 1)) * 2.0 - 1.0
        row_buf = []
        for x in range(grid_cols):
            nx = (x / max(1, grid_cols - 1)) * 2.0 - 1.0
            # Gyroscopic 3D wave interference (liquid surface height)
            wave1 = math.sin((nx * 3.2 + gx * 1.5) + phase * 2.2)
            wave2 = math.cos((ny * 3.2 + gy * 1.5) - phase * 1.7)
            ripple = math.sin(math.sqrt((nx + gz * 0.25) ** 2 + ny ** 2) * 5.0 - phase * 3.0)
            height = clamp((wave1 + wave2 + ripple) / 3.0 * 0.5 + 0.5, 0.0, 1.0)

            cell_hue = (hue_base + height * 65.0 + nx * 18.0) % 360.0
            cell_val = clamp(0.35 + height * 0.65, 0.0, 1.0)
            cr, cg, cb = [int(c * 255) for c in colorsys.hsv_to_rgb(cell_hue / 360.0, 0.9, cell_val)]

            glyph = liquid_chars[int(height * (len(liquid_chars) - 1))]
            row_buf.append(f"\033[38;2;{cr};{cg};{cb}m{glyph}")
        row_buf.append("\033[0m")
        lines.append("".join(row_buf))

    lines.append("Press Ctrl+C to exit.")
    sys.stdout.write("\n".join(lines))
    sys.stdout.flush()


def main():
    phase = 0.0
    try:
        while True:
            gx, gy, gz, source = read_gyro_sample()
            render_frame(gx, gy, gz, source, phase)
            phase += 0.08
            time.sleep(0.06)
    except KeyboardInterrupt:
        sys.stdout.write("\033[0m\033[?25h\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
PYEOF

chmod +x ~/gyro_liquid_3d/gyro_liquid.py
echo "Generated ~/gyro_liquid_3d/gyro_liquid.py. Run: python ~/gyro_liquid_3d/gyro_liquid.py"
