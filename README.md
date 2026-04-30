# codetracer-image-diff

Neighborhood-aware visual-diff for `CodeTracer visual-replay`'s
software-vs-hardware integration tests. Wraps NVIDIA's FLIP
(*A Difference Evaluator for Alternating Images*, Andersson et al.,
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

## Spec

Design lives in `an internal design document`:
[`the snapshot tooling design`](an internal design document).
Milestone status:
[`the snapshot tooling design`](an internal design document).

## Status

Bootstrap (the library milestone) pending.

## Citation

Andersson, P. and Nilsson, J. and Akenine-Möller, T. and Oskarsson, M.
and Åström, K. and Fairchild, M. D., *FLIP: A Difference Evaluator
for Alternating Images*, Proceedings of the ACM on Computer Graphics
and Interactive Techniques, 3 (2), 2020.
https://research.nvidia.com/publication/2020-07_FLIP

## License

BSD-3, matching upstream NVIDIA FLIP.
