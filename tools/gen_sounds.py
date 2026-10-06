#!/usr/bin/env python3
"""
Project Azmuth - gerador de sons do Omnitrix (procedural, sem samples externos).

Gera em assets/sounds/:
  transform.wav  — transformação (sweep ascendente + estouro de energia)
  neutral.wav    — "destransformação" / volta ao Neutral (sweep descendente)
  hud_open.wav   — o core saltando do relógio
  tick.wav       — clique do disco girando
  error.wav      — DNA bloqueado / falha (bip-bip grave)

Uso (dependência só de dev: numpy):
  .venv/bin/python tools/gen_sounds.py
"""

import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def t_axis(seconds: float) -> np.ndarray:
    return np.linspace(0, seconds, int(RATE * seconds), endpoint=False)


def sweep(f0: float, f1: float, seconds: float, curve: float = 2.0) -> np.ndarray:
    """Seno com frequência variando de f0 a f1 (exponencial-ish), fase contínua."""
    t = t_axis(seconds)
    k = (t / seconds) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)


def tone(freq: float, seconds: float) -> np.ndarray:
    t = t_axis(seconds)
    return np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t)


def envelope(n: int, attack: float = 0.01, release: float = 0.1) -> np.ndarray:
    env = np.ones(n)
    a, r = int(RATE * attack), int(RATE * release)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[-r:] *= np.linspace(1, 0, r)
    return env


def noise(seconds: float, decay: float) -> np.ndarray:
    t = t_axis(seconds)
    return np.random.default_rng(10).uniform(-1, 1, t.size) * np.exp(-t / decay)


def mix_at(base: np.ndarray, layer: np.ndarray, at: float, gain: float = 1.0) -> np.ndarray:
    start = int(RATE * at)
    end = start + layer.size
    if end > base.size:
        base = np.concatenate([base, np.zeros(end - base.size)])
    base[start:end] += layer * gain
    return base


def save(name: str, signal: np.ndarray, volume: float = 0.6) -> None:
    signal = signal / (np.max(np.abs(signal)) or 1) * volume
    data = (signal * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"[OK] {name}")


def transform() -> np.ndarray:
    whine = sweep(220, 2400, 0.55, curve=2.4) * envelope(int(RATE * 0.55), 0.05, 0.02)
    out = np.zeros(int(RATE * 1.2))
    out = mix_at(out, whine, 0.0, 0.7)
    # estouro: grave + ruído
    boom_t = t_axis(0.6)
    boom = np.sin(2 * np.pi * (90 - 50 * boom_t) * boom_t) * np.exp(-boom_t / 0.18)
    out = mix_at(out, boom, 0.55, 1.0)
    out = mix_at(out, noise(0.5, 0.08), 0.55, 0.45)
    # brilho final
    sparkle = tone(1760, 0.25) * np.exp(-t_axis(0.25) / 0.07)
    out = mix_at(out, sparkle, 0.62, 0.3)
    return out


def neutral() -> np.ndarray:
    down = sweep(1800, 160, 0.9, curve=0.6) * envelope(int(RATE * 0.9), 0.01, 0.3)
    out = np.zeros(int(RATE * 1.0))
    out = mix_at(out, down, 0.0, 0.8)
    out = mix_at(out, noise(0.3, 0.05), 0.0, 0.2)
    return out


def hud_open() -> np.ndarray:
    out = np.zeros(int(RATE * 0.45))
    out = mix_at(out, noise(0.06, 0.012), 0.0, 0.8)  # "clack" mecânico
    chirp = sweep(600, 1500, 0.18, curve=1.0) * envelope(int(RATE * 0.18), 0.005, 0.08)
    out = mix_at(out, chirp, 0.05, 0.6)
    out = mix_at(out, tone(1500, 0.12) * envelope(int(RATE * 0.12), 0.005, 0.1), 0.24, 0.35)
    return out


def tick() -> np.ndarray:
    t = t_axis(0.035)
    return np.sin(2 * np.pi * 2600 * t) * np.exp(-t / 0.006) + noise(0.035, 0.004) * 0.6


def error() -> np.ndarray:
    beep = tone(330, 0.12) * envelope(int(RATE * 0.12), 0.005, 0.03)
    out = np.zeros(int(RATE * 0.4))
    out = mix_at(out, beep, 0.0)
    out = mix_at(out, beep, 0.2)
    return out


if __name__ == "__main__":
    save("transform.wav", transform())
    save("neutral.wav", neutral())
    save("hud_open.wav", hud_open(), 0.5)
    save("tick.wav", tick(), 0.35)
    save("error.wav", error(), 0.5)
