# Patches applied to vendored FLIP source

**Formatting only.** The vendored `FLIP.h` (commit `b475eb4`, FLIP v1.7)
retains its upstream logic with leading-whitespace normalization. The single-header file compiles cleanly under

    g++ -std=c++17 -O2 -DNDEBUG src/flip_wrapper.cpp

when `FLIP_ENABLE_CUDA` is left undefined, which is our default. The
CUDA-only code paths inside `FLIP.h` are guarded by
`#ifdef FLIP_ENABLE_CUDA` and are not compiled.

If a future toolchain change requires modifications, document each
patch here as a _unified diff_ with a one-paragraph rationale and an
explicit promise that no algorithmic logic was touched. The agreement
with upstream is: vendor verbatim where possible; build-glue patches
only.

The 2026-10-04 formatting patch changes leading indentation only. All
non-leading bytes, literals and preprocessor continuations are preserved.
See [the vendor formatting record](../FORMATTING-PATCHES.md).

```diff
--- a/vendor/flip/FLIP.h
+++ b/vendor/flip/FLIP.h
@@ -30,21 +30,21 @@
  * SPDX-License-Identifier: BSD-3-Clause
  */

- // Visualizing and Communicating Errors in Rendered Images
- // Ray Tracing Gems II, 2021,
- // by Pontus Andersson, Jim Nilsson, and Tomas Akenine-Moller.
- // Pointer to the chapter: https://research.nvidia.com/publication/2021-08_Visualizing-and-Communicating.
-
- // Visualizing Errors in Rendered High Dynamic Range Images
- // Eurographics 2021,
- // by Pontus Andersson, Jim Nilsson, Peter Shirley, and Tomas Akenine-Moller.
- // Pointer to the paper: https://research.nvidia.com/publication/2021-05_HDR-FLIP.
-
- // FLIP: A Difference Evaluator for Alternating Images
- // High Performance Graphics 2020,
- // by Pontus Andersson, Jim Nilsson, Tomas Akenine-Moller,
- // Magnus Oskarsson, Kalle Astrom, and Mark D. Fairchild.
- // Pointer to the paper: https://research.nvidia.com/publication/2020-07_FLIP.
+  // Visualizing and Communicating Errors in Rendered Images
+  // Ray Tracing Gems II, 2021,
+  // by Pontus Andersson, Jim Nilsson, and Tomas Akenine-Moller.
+  // Pointer to the chapter: https://research.nvidia.com/publication/2021-08_Visualizing-and-Communicating.
+
+  // Visualizing Errors in Rendered High Dynamic Range Images
+  // Eurographics 2021,
+  // by Pontus Andersson, Jim Nilsson, Peter Shirley, and Tomas Akenine-Moller.
+  // Pointer to the paper: https://research.nvidia.com/publication/2021-05_HDR-FLIP.
+
+  // FLIP: A Difference Evaluator for Alternating Images
+  // High Performance Graphics 2020,
+  // by Pontus Andersson, Jim Nilsson, Tomas Akenine-Moller,
+  // Magnus Oskarsson, Kalle Astrom, and Mark D. Fairchild.
+  // Pointer to the paper: https://research.nvidia.com/publication/2020-07_FLIP.

 // Single header code by Pontus Ebelin (formerly Andersson) and Tomas Akenine-Moller.
 //
@@ -2319,11 +2319,11 @@
      * @param[in] useHDR Set to true if the input images are to be considered containing HDR content, i.e., not necessarily in [0,1].
      * @param[in,out] parameters Contains parameters (e.g., PPD, exposure settings,etc). If the exposures have not been set by the user, then those will be computed (and returned).
      * @param[out] errorMapFLIPOutput The FLIP error image in [0,1], a single channel (grayscale).
-                   The user should map it using MapMagma if that is desired (with: errorMapWithMagma.colorMap(errorMapFLIP, FLIP::magmaMap);)
+                    The user should map it using MapMagma if that is desired (with: errorMapWithMagma.colorMap(errorMapFLIP, FLIP::magmaMap);)
      * @param[out] maxErrorExposureMapOutput Exposure map output (only for HDR content).
      * @param[in] returnIntermediateLDRFLIPImages True if the next argument should be filled in by FLIP::evaluate().
      * @param[out] intermediateLDRFLIPImages A list of temporary output LDR-FLIP error maps (in grayscale) from HDR-FLIP.
-                   See explanation of the errorMapFLIPOutput parameter for how to convert the maps to magma.
+                    See explanation of the errorMapFLIPOutput parameter for how to convert the maps to magma.
      * @param[in] returnIntermediateLDRImages True if the next argument should be filled in by FLIP::evaluate().
      * @param[out] intermediateLDRImages A list of temporary tonemapped output LDR images (in linear RGB) from HDR-FLIP. Images in this order: Ref0, Test0, Ref1, Test1,...
      */
@@ -2406,7 +2406,7 @@

     // This variant does not return any LDR images computed by HDR-FLIP and thus avoids two parameters (since using those is a rare use case).
     static void evaluate(FLIP::image<FLIP::color3>& referenceImageInput, FLIP::image<FLIP::color3>& testImageInput,
-         const bool useHDR, FLIP::Parameters& parameters, FLIP::image<float>& errorMapFLIPOutput, FLIP::image<float>& maxErrorExposureMapOutput)
+          const bool useHDR, FLIP::Parameters& parameters, FLIP::image<float>& errorMapFLIPOutput, FLIP::image<float>& maxErrorExposureMapOutput)
     {
         std::vector<FLIP::image<float>*> intermediateLDRFLIPImages;
         std::vector<FLIP::image<FLIP::color3>*> intermediateLDRImages;
@@ -2415,7 +2415,7 @@

     // This variant does not return the exposure map, which may also be used quite seldom.
     static void evaluate(FLIP::image<FLIP::color3>& referenceImageInput, FLIP::image<FLIP::color3>& testImageInput, const bool useHDR, FLIP::Parameters& parameters,
-         FLIP::image<float>& errorMapFLIPOutput)
+          FLIP::image<float>& errorMapFLIPOutput)
     {
         FLIP::image<float> maxErrorExposureMapOutput(referenceImageInput.getWidth(), referenceImageInput.getHeight());
         FLIP::evaluate(referenceImageInput, testImageInput, useHDR, parameters, errorMapFLIPOutput, maxErrorExposureMapOutput);
```
