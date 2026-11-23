#!/data/data/com.termux/files/usr/bin/python
import argparse
import cmath
import colorsys
import json
import math
import os
import shutil
import subprocess
import time

STATE_FILE = os.path.expanduser("~/qbit_audio_lab/audio_state.json")


def default_state():
    return {
        "tick": 0,
        "locked_hz": None,
        "locked_hue": None,
        "audio_core": {
            "base_hz": 220.0,
            "amplitude": 0.5,
            "harmonic_ratio": 1.5,
        },
        "qbits": [
            {"id": "q0", "theta": 0.4, "phi": 0.0, "prob_one": 0.04},
            {"id": "q1", "theta": 0.8, "phi": 1.2, "prob_one": 0.17},
        ],
        "engines": {
            "active": "audio_wave_engine",
            "rpm": 1200.0,
            "load": 0.35,
        },
        "qbit_engines": {
            "mode": "phase_harmonic_drive",
            "coherence": 0.92,
            "coupling": 0.65,
        },
        "unreal_engines": {
            "profile": "spatial_audio_scene",
            "frame_ms": 16.6,
            "world_units": [0.0, 0.0, 0.0],
        },
        "qbit_unreal_engines": {
            "bridge": "qbit_audio_to_scene_matrix",
            "entanglement_gain": 0.78,
            "active_hz": 220.0,
            "render_hue": 210.0,
        },
    }


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        base = default_state()
        for k, v in base.items():
            if k not in data:
                data[k] = v
            elif isinstance(v, dict) and isinstance(data[k], dict):
                for sub_k, sub_v in v.items():
                    data[k].setdefault(sub_k, sub_v)
        return data
    return default_state()


def save_state(state):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)


def maybe_speak(text, enabled):
    if enabled and shutil.which("termux-tts-speak"):
        try:
            subprocess.run(
                ["termux-tts-speak", text],
                capture_output=True,
                text=True,
                timeout=3.0,
            )
        except Exception:
            pass


def step_audio_simulation(state, steps=1, gx=0.4, gy=-0.3, gz=0.2):
    for _ in range(max(1, steps)):
        state["tick"] += 1
        t = state["tick"] * 0.1

        # 1. Qbits: update Bloch angle theta, phase phi, and |1> probability
        q_energy = 0.0
        for idx, q in enumerate(state["qbits"]):
            q["phi"] = (q["phi"] + 0.25 + gx * 0.15 + idx * 0.1) % (2.0 * math.pi)
            q["theta"] = (math.pi * 0.5) * (0.5 + 0.5 * math.sin(t + idx + gy))
            amp1 = math.sin(q["theta"] / 2.0) * cmath.exp(1j * q["phi"])
            q["prob_one"] = round(abs(amp1) ** 2, 4)
            q_energy += q["prob_one"]

        mean_q = q_energy / max(1, len(state["qbits"]))

        # 2. Engines: classical engine load & rpm
        eng = state["engines"]
        eng["load"] = round(
            min(1.0, max(0.05, 0.3 + 0.25 * abs(math.sin(t)) + 0.1 * abs(gz))), 4
        )
        eng["rpm"] = round(900.0 + eng["load"] * 2600.0, 1)

        # 3. Qbit Engines: couple qbit probability with engine load & coherence
        qe = state["qbit_engines"]
        qe["coherence"] = round(
            max(0.1, min(1.0, 0.95 - 0.15 * eng["load"] + 0.05 * mean_q)), 4
        )
        qe["coupling"] = round(min(1.0, max(0.0, 0.4 + 0.6 * mean_q)), 4)

        # 4. Unreal Engines: spatial audio scene coordinates & frame timing
        ue = state["unreal_engines"]
        ue["world_units"] = [
            round(math.cos(t + gx) * 100.0, 2),
            round(math.sin(t + gy) * 100.0, 2),
            round(math.sin(t * 0.5 + gz) * 25.0, 2),
        ]
        ue["frame_ms"] = round(12.0 + eng["load"] * 10.0, 2)

        # Audio core & Qbit Unreal Engines bridge
        ac = state["audio_core"]
        ac["amplitude"] = round(min(1.0, max(0.05, 0.25 + 0.55 * qe["coupling"])), 4)
        ac["harmonic_ratio"] = round(1.0 + 1.5 * mean_q, 4)

        que = state["qbit_unreal_engines"]
        que["entanglement_gain"] = round(
            min(1.0, qe["coherence"] * qe["coupling"] + 0.15), 4
        )

        if state["locked_hz"] is not None:
            hz = float(state["locked_hz"])
        else:
            hz = round(
                max(55.0, min(1760.0, ac["base_hz"] * (1.0 + 0.5 * math.sin(t + mean_q * 3.0)))),
                2,
            )
        que["active_hz"] = hz

        if state["locked_hue"] is not None:
            que["render_hue"] = round(float(state["locked_hue"]) % 360.0, 1)
        else:
            # Map frequency onto the 360-degree wheel via log2 ratio from A4 (440 Hz)
            semitone_offset = 12.0 * math.log2(max(1.0, hz) / 440.0)
            que["render_hue"] = round((210.0 + semitone_offset * 15.0) % 360.0, 1)

    return state


def format_report(state):
    que = state["qbit_unreal_engines"]
    hue = que["render_hue"]
    hz = que["active_hz"]
    r_f, g_f, b_f = colorsys.hsv_to_rgb(hue / 360.0, 0.88, 0.92)
    r, g, b = int(r_f * 255), int(g_f * 255), int(b_f * 255)
    hex_code = f"#{r:02X}{g:02X}{b:02X}"

    locks = []
    if state["locked_hz"] is not None:
        locks.append(f"HZ={state['locked_hz']}Hz")
    if state["locked_hue"] is not None:
        locks.append(f"HUE={state['locked_hue']}deg")
    lock_label = "LOCKED (" + ", ".join(locks) + ")" if locks else "UNLOCKED"

    lines = [
        f"=== QBIT AUDIO & ENGINE MATRIX | TICK {state['tick']} | {lock_label} ===",
        f"Audio & Color Bridge: {hz} Hz | {hex_code} RGB({r},{g},{b}) Hue={hue} deg",
        f"[audio_core]         {state['audio_core']}",
        f"[qbits]              {state['qbits']}",
        f"[engines]            {state['engines']}",
        f"[qbit_engines]       {state['qbit_engines']}",
        f"[unreal_engines]     {state['unreal_engines']}",
        f"[qbit_unreal_engines]{state['qbit_unreal_engines']}",
        f"State file: {STATE_FILE}",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Termux audio simulation across Qbits, Engines, Qbit Engines, Unreal Engines, and Qbit Unreal Engines"
    )
    parser.add_argument("--steps", type=int, default=1, help="Number of simulation ticks to advance")
    parser.add_argument("--lock-hz", type=float, help="Lock audio frequency in Hz (e.g. 440)")
    parser.add_argument("--lock-hue", type=float, help="Lock render hue in degrees (0-360)")
    parser.add_argument("--unlock", action="store_true", help="Unlock both Hz and Hue")
    parser.add_argument("--reset", action="store_true", help="Reset saved audio state")
    parser.add_argument("--watch", action="store_true", help="Continuously step every 0.5s")
    parser.add_argument("--speak", action="store_true", help="Speak frequency via termux-tts-speak if available")
    args = parser.parse_args()

    state = default_state() if args.reset else load_state()
    if args.unlock:
        state["locked_hz"] = None
        state["locked_hue"] = None
    else:
        if args.lock_hz is not None:
            state["locked_hz"] = float(args.lock_hz)
        if args.lock_hue is not None:
            state["locked_hue"] = float(args.lock_hue) % 360.0

    if args.watch:
        try:
            while True:
                step_audio_simulation(state, steps=1)
                save_state(state)
                print("\033[H\033[2J" + format_report(state), flush=True)
                maybe_speak(f"{state['qbit_unreal_engines']['active_hz']} hertz", args.speak)
                time.sleep(0.5)
        except KeyboardInterrupt:
            print("\nStopped audio watch mode.")
        return

    step_audio_simulation(state, steps=max(1, args.steps))
    save_state(state)
    print(format_report(state))
    maybe_speak(f"{state['qbit_unreal_engines']['active_hz']} hertz", args.speak)


if __name__ == "__main__":
    main()
