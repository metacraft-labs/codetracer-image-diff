# codetracer-image-diff

Neighborhood-aware visual-diff for CodeTracer's visual-replay
software-vs-hardware integration tests. Wraps NVIDIA's FLIP
(_A Difference Evaluator for Alternating Images_, Andersson et al.,
HPG 2020) — a perceptual metric that combines a contrast-sensitivity
pass and a feature-detection pass to produce per-pixel error in
[0, 1] that tolerates rasterizer-level noise without false-passing
on real differences.

## Why FLIP, not SSIM / Butteraugli / per-pixel ΔE

- **Per-pixel ΔE / RMS:** false-positives on a 1-pixel edge shift,
  which is normal noise between Mesa and NVIDIA rasterization.
- **SSIM:** designed for compression-artifact perception, not
  rendering-pipeline noise. Tends to under-report structural
  differences in flat regions.
- **Butteraugli:** good ratio-perception, but its error map smears
  small differences across many pixels, so the localization is
  poor for "which draw call diverged".
- **FLIP:** built for exactly this case. NVIDIA's reference
  implementation has a CPU build that's small enough to vendor.

## Design notes

The library exists to compare a frame rendered by CodeTracer's software
replay path against the same frame rendered through the hardware path.
The two legitimately differ by rasterizer-level noise (rounding,
anti-aliasing and filtering differences between GPU drivers and a
software rasterizer), so a plain per-pixel comparison is too strict.

- Inputs are sRGB-encoded 8-bit RGBA framebuffers of equal size.
- FLIP's LDR mode is used. The wrapper converts the sRGB bytes to linear
  RGB floats in [0, 1] before evaluation, because FLIP's LDR path
  expects linear input internally.
- Viewing-condition parameters are FLIP's upstream defaults (0.7 m
  viewing distance, 3840 px screen width, 0.7 m monitor width).
- Output is a per-pixel error map in [0, 1] plus summary statistics, and
  `renderFlipPng(...)` renders the map as a PNG for inspection.
- Only the CPU implementation is built; CUDA is never enabled.

## Status

The library bootstrap is implemented: vendored FLIP.h v1.7, public
`flip(...)` and `renderFlipPng(...)` Nim API, and four passing tests
(identical / different / subpixel-shift / PNG round-trip).

## Citation

Andersson, P. and Nilsson, J. and Akenine-Möller, T. and Oskarsson, M.
and Åström, K. and Fairchild, M. D., _FLIP: A Difference Evaluator
for Alternating Images_, Proceedings of the ACM on Computer Graphics
and Interactive Techniques, 3 (2), 2020.
https://research.nvidia.com/publication/2020-07_FLIP

## License

This project is released under the BSD 3-Clause License; see
[`LICENSE`](LICENSE). Vendored third-party code keeps its own license:

- [`vendor/flip/LICENSE`](vendor/flip/LICENSE) - NVIDIA FLIP (BSD 3-Clause)
- [`vendor/stb/LICENSE`](vendor/stb/LICENSE) - stb_image_write (MIT or public domain)
