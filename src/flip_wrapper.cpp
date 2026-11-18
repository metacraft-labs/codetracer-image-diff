/*
 * codetracer-image-diff — C ABI shim for NVIDIA FLIP (CPU build).
 *
 * This translation unit instantiates the upstream single-header
 * implementation (vendor/flip/FLIP.h) and exposes ct_flip_compute()
 * with C linkage so Nim's importc can bind it.
 *
 * The wrapper's contract is:
 *   - Input pixels are sRGB-encoded 8-bit bytes (the replay player's
 *     framebuffers, which are LDR, so FLIP's LDR mode applies). Convert
 *     to linear-RGB float in [0, 1]
 *     before handing to FLIP::evaluate, since the upstream LDR path
 *     expects linear RGB internally (see FLIP.h:2237 comment on
 *     LDR_FLIP).
 *   - The CSF / viewing-distance parameters use FLIP's upstream
 *     defaults (PPD computed from 0.7 m viewing distance, 3840 px
 *     screen width, 0.7 m monitor width; see FLIP.h:108).
 *
 * No CUDA paths are compiled; we never define FLIP_ENABLE_CUDA.
 */

#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <new>

// Pull in the entire FLIP single-header implementation.
#include "FLIP.h"

#include "flip_wrapper.h"

namespace {

// sRGB 8-bit -> linear-RGB float, per IEC 61966-2-1.
// We use a precomputed 256-entry lookup; the math is the standard piecewise
// approximation:
//   if (s <= 0.04045) lin = s / 12.92;
//   else              lin = pow((s + 0.055) / 1.055, 2.4);
//
// Computed at static-init time; the table is small (1 KB) and the
// initialization runs once per process.
struct SrgbToLinearLUT {
    float table[256];
    SrgbToLinearLUT() {
        for (int i = 0; i < 256; ++i) {
            float s = float(i) / 255.0f;
            float lin = (s <= 0.04045f)
                ? (s / 12.92f)
                : std::pow((s + 0.055f) / 1.055f, 2.4f);
            table[i] = lin;
        }
    }
};

const SrgbToLinearLUT g_srgbLut;

inline void srgbBufferToLinearFloat(const unsigned char *src,
                                    int width, int height, int channels,
                                    float *dst /* width*height*3 */) {
    const int n = width * height;
    for (int i = 0; i < n; ++i) {
        const unsigned char *p = src + i * channels;
        dst[i * 3 + 0] = g_srgbLut.table[p[0]];
        dst[i * 3 + 1] = g_srgbLut.table[p[1]];
        dst[i * 3 + 2] = g_srgbLut.table[p[2]];
        // Alpha (channels==4) intentionally ignored: FLIP is a colour
        // metric, not a compositing one. Tests that need alpha-aware
        // diffs should pre-compose against a known background.
    }
}

} // namespace

extern "C" int ct_flip_compute(const unsigned char *reference,
                                const unsigned char *candidate,
                                int width, int height, int channels,
                                float **out_error_map) {
    if (out_error_map == nullptr) return 1;
    *out_error_map = nullptr;

    if (reference == nullptr || candidate == nullptr) return 2;
    if (width <= 0 || height <= 0) return 3;
    if (channels != 3 && channels != 4) return 4;

    const int npix = width * height;
    if (npix <= 0) return 3;

    // Allocate the linearized float buffers (3 channels per pixel,
    // matching FLIP::color3). new[] for exception-safety; we explicitly
    // catch bad_alloc and translate to an error code so we never throw
    // across the C ABI boundary.
    float *refLin = nullptr;
    float *candLin = nullptr;
    try {
        refLin  = new float[size_t(npix) * 3];
        candLin = new float[size_t(npix) * 3];
    } catch (const std::bad_alloc &) {
        delete[] refLin;
        delete[] candLin;
        return 5;
    }

    srgbBufferToLinearFloat(reference, width, height, channels, refLin);
    srgbBufferToLinearFloat(candidate, width, height, channels, candLin);

    float *errMap = nullptr;
    try {
        FLIP::Parameters params;  // Upstream defaults (see FLIP.h:108).
        float meanFlip = 0.0f;
        FLIP::evaluate(
            refLin, candLin,
            width, height,
            /*useHDR=*/false,
            params,
            /*applyMagmaMapToOutput=*/false,
            /*computeMeanFLIPError=*/false,
            meanFlip,
            &errMap);
    } catch (const std::bad_alloc &) {
        delete[] refLin;
        delete[] candLin;
        return 6;
    } catch (...) {
        // Translate any other exception into a generic error. FLIP's LDR
        // path is not expected to throw under normal use, but we fence
        // the C-ABI boundary regardless.
        delete[] refLin;
        delete[] candLin;
        if (errMap != nullptr) delete[] errMap;
        return 7;
    }

    delete[] refLin;
    delete[] candLin;

    if (errMap == nullptr) return 8;

    // FLIP::evaluate allocated the error map with `new float[...]`. The
    // contract documented in flip_wrapper.h says callers free with
    // free(), so we copy into a malloc'd block and release the new[]'d
    // one. Mixing new[]/free is undefined behaviour, hence the copy.
    float *malloced = static_cast<float *>(std::malloc(size_t(npix) * sizeof(float)));
    if (malloced == nullptr) {
        delete[] errMap;
        return 9;
    }
    std::memcpy(malloced, errMap, size_t(npix) * sizeof(float));
    delete[] errMap;

    *out_error_map = malloced;
    return 0;
}
