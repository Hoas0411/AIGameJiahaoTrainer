# Procedural, tileable surface maps for the Training Yard Kit (self-authored, CC0).
# Run: python make_textures.py   (numpy + Pillow). Outputs 512px periodic maps.
import numpy as np
from PIL import Image
N = 512
rng = np.random.default_rng(20261009)

def periodic_noise(scale_px, power=2.0):
    """Band-limited periodic noise: white noise filtered in the frequency domain."""
    w = rng.standard_normal((N, N))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(N)[:, None]
    kx = np.fft.fftfreq(N)[None, :]
    k = np.sqrt(kx * kx + ky * ky) + 1e-6
    k0 = 1.0 / scale_px
    filt = np.exp(-(k / k0) ** power)
    n = np.real(np.fft.ifft2(f * filt))
    n -= n.min(); n /= n.max()
    return n

def save_gray(a, name):
    Image.fromarray(np.clip(a * 255.0, 0, 255).astype(np.uint8), 'L').save(name)

def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    rgb = np.stack([(-dx / l) * 0.5 + 0.5, (dy / l) * 0.5 + 0.5, (nz / l) * 0.5 + 0.5], -1)
    Image.fromarray((rgb * 255).astype(np.uint8), 'RGB').save(
        'tmp.png') if False else None
    return rgb

def save_rgb(rgb, name):
    Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8), 'RGB').save(name)

# Coated metal: soft orange-peel paint texture + faint low-frequency mottling.
peel = periodic_noise(3.0, 2.0)
mottle = periodic_noise(90.0, 2.0)
h = peel * 0.85 + mottle * 0.15
save_rgb(normal_from_height(h, 2.2), 'coated_normal.png')
save_gray(0.42 + 0.22 * mottle + 0.10 * (peel - 0.5), 'coated_roughness.png')

# Floor plate: fine anisotropic sanding marks (stretched noise) + wear mottling.
w = rng.standard_normal((N, N))
f = np.fft.fft2(w)
ky = np.fft.fftfreq(N)[:, None]; kx = np.fft.fftfreq(N)[None, :]
filt = np.exp(-((kx / 0.25) ** 2 + (ky / 0.008) ** 2))
brushed = np.real(np.fft.ifft2(f * filt)); brushed = (brushed - brushed.min()) / (brushed.max() - brushed.min())
wear = periodic_noise(60.0, 2.0)
save_rgb(normal_from_height(brushed * 0.6 + periodic_noise(4.0) * 0.4, 1.6), 'floor_normal.png')
save_gray(0.52 + 0.20 * wear + 0.08 * (brushed - 0.5), 'floor_roughness.png')
print('textures written')
