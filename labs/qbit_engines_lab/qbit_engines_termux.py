import argparse
import cmath
import colorsys
import json
import math
import os
import time

STATE_FILE = os.path.expanduser("~/qbit_engines_lab/state.json")

LAYERS = (
    "qbits",
    "engines",
    "qbit_engines",
    "unreal_engines",
    "qbit_unreal_engines",
)


def default_state():
    return {
        "tick": 0,
        "locked_hue": None,
        "qbits": [
            {"id": "q0", "theta": 0.4, "phi": 0.0, "prob_one": 0.04},
            {"id": "q1", "theta": 0.8, "phi": 1.2, "prob_one": 0.17},
        ],
        "engines": {
            "active": "core_liquid_engine",
            "rpm": 1200.0,
            "load": 0.35,
        },
        "qbit_engines": {
            "mode": "superposition_drive",
            "coherence": 0.92,
            "coupling": 0.65,
        },
        "unreal_engines": {
            "profile": "realtime_scene_sim",
            "frame_ms": 16.6,
            "world_units": [0.0, 0.0, 0.0],
        },
        "qbit_unreal_engines": {
            "bridge": "qbit_to_scene_matrix",
            "entanglement_gain": 0.78,
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


def step_simulation(state, steps=1, gx=0.4, gy=-0.3, gz=0.2):
    for _ in range(max(1, steps)):
        state["tick"] += 1
        t = state["tick"] * 0.1

        # 1. Qbits: update Bloch-like polar angle theta, phase phi, and |1> probability
        q_energy = 0.0
        for idx, q in enumerate(state["qbits"]):
            q["phi"] = (q["phi"] + 0.25 + gx * 0.15 + idx * 0.1) % (2.0 * math.pi)
            q["theta"] = (math.pi * 0.5) * (0.5 + 0.5 * math.sin(t + idx + gy))
            amp1 = math.sin(q["theta"] / 2.0) * cmath.exp(1j * q["phi"])
            q["prob_one"] = round(abs(amp1) ** 2, 4)
            q_energy += q["prob_one"]

        mean_q = q_energy / max(1, len(state["qbits"]))

        # 2. Engines: classical deterministic engine tick
        eng = state["engines"]
        eng["load"] = round(min(1.0, max(0.05, 0.3 + 0.25 * abs(math.sin(t)) + 0.1 * abs(gz))), 4)
        eng["rpm"] = round(900.0 + eng["load"] * 2600.0, 1)

        # 3. Qbit Engines: couple qbit probability with engine load & coherence
        qe = state["qbit_engines"]
        qe["coherence"] = round(max(0.1, min(1.0, 0.95 - 0.15 * eng["load"] + 0.05 * mean_q)), 4)
        qe["coupling"] = round(min(1.0, max(0.0, 0.4 + 0.6 * mean_q)), 4)

        # 4. Unreal Engines: advance simulated scene coordinates & frame timing
        ue = state["unreal_engines"]
        ue["world_units"] = [
            round(math.cos(t + gx) * 100.0, 2),
            round(math.sin(t + gy) * 100.0, 2),
            round(math.sin(t * 0.5 + gz) * 25.0, 2),
        ]
        ue["frame_ms"] = round(12.0 + eng["load"] * 10.0, 2)

        # 5. Qbit Unreal Engines: merge qbit engine coupling + scene motion into wheel hue
        que = state["qbit_unreal_engines"]
        que["entanglement_gain"] = round(min(1.0, qe["coherence"] * qe["coupling"] + 0.15), 4)
        if state["locked_hue"] is not None:
            que["render_hue"] = round(float(state["locked_hue"]) % 360.0, 1)
        else:
            que["render_hue"] = round((state["tick"] * 12.0 + gx * 30.0 + mean_q * 90.0) % 360.0, 1)

    return state


def format_report(state):
    hue = state["qbit_unreal_engines"]["render_hue"]
    r_f, g_f, b_f = colorsys.hsv_to_rgb(hue / 360.0, 0.88, 0.92)
    r, g, b = int(r_f * 255), int(g_f * 255), int(b_f * 255)
    hex_code = f"#{r:02X}{g:02X}{b:02X}"
    lock_label = f"LOCKED ({state['locked_hue']} deg)" if state["locked_hue"] is not None else "UNLOCKED"

    lines = [
        f"=== QBIT & ENGINE MATRIX | TICK {state['tick']} | {lock_label} ===",
        f"Color Bridge: {hex_code} RGB({r},{g},{b}) Hue={hue} deg",
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
        description="Termux simulator for Qbits, Engines, Qbit Engines, Unreal Engines, and Qbit Unreal Engines"
    )
    parser.add_argument("--steps", type=int, default=1, help="Number of simulation ticks to advance")
    parser.add_argument("--lock-hue", type=float, help="Lock render hue (0-360 deg)")
    parser.add_argument("--unlock", action="store_true", help="Unlock render hue")
    parser.add_argument("--reset", action="store_true", help="Reset saved state to defaults")
    parser.add_argument("--watch", action="store_true", help="Continuously step and print every 0.5s")
    args = parser.parse_args()

    state = default_state() if args.reset else load_state()
    if args.unlock:
        state["locked_hue"] = None
    elif args.lock_hue is not None:
        state["locked_hue"] = float(args.lock_hue) % 360.0

    if args.watch:
        try:
            while True:
                step_simulation(state, steps=1)
                save_state(state)
                print("\033[H\033[2J" + format_report(state), flush=True)
                time.sleep(0.5)
        except KeyboardInterrupt:
            print("\nStopped watch mode.")
        return

    step_simulation(state, steps=max(1, args.steps))
    save_state(state)
    print(format_report(state))


if __name__ == "__main__":
    main()
