/*
 * codetracer-image-diff — C ABI shim for NVIDIA FLIP (CPU build).
 *
 * The upstream FLIP API (FLIP::evaluate) is C++ only and uses
 * std::string / std::vector / FLIP::image template machinery in its
 * signatures. This header exposes a minimal C-linkage entry point that
 * Nim's importc can bind directly.
 *
 * The wrapper accepts an sRGB byte buffer (3 or 4 channels per pixel —
 * RGB or RGBA), converts to FLIP's expected linear-RGB float input, and
 * runs the LDR FLIP path with the upstream defaults. The output is a
 * width*height grayscale float error map in [0, 1] that the caller
 * receives as a freshly-allocated array. Caller frees with `free()`.
 */
#ifndef CT_FLIP_WRAPPER_H
#define CT_FLIP_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Compute the FLIP error map between `reference` and `candidate`.
 *
 *   reference, candidate : sRGB byte buffers, length = width*height*channels.
 *   width, height        : image dimensions in pixels (both > 0).
 *   channels             : 3 (RGB) or 4 (RGBA). Alpha is ignored.
 *   out_error_map        : on success, *out_error_map points to a
 *                          width*height float32 array allocated with
 *                          malloc(). Caller frees with free().
 *
 * Returns 0 on success, non-zero on error (bad arguments, out of memory).
 * On error *out_error_map is set to NULL.
 */
int ct_flip_compute(const unsigned char *reference,
                    const unsigned char *candidate,
                    int width, int height, int channels,
                    float **out_error_map);

#ifdef __cplusplus
}
#endif

#endif /* CT_FLIP_WRAPPER_H */
