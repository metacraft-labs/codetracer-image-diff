## codetracer-image-diff — perceptual image diff for visual-replay tests.
##
## Wraps NVIDIA's FLIP CPU implementation (see `vendor/flip/`) and
## exposes a single high-level entry point: `flip(reference, candidate,
## width, height)` returns a `FlipResult` containing the per-pixel error
## map plus summary statistics (mean, p50/p90/p99, max).
##
## Inputs are sRGB byte buffers (3- or 4-channel). The wrapper uses
## FLIP's *LDR* mode with the upstream's default monitor/viewing-distance
## parameters (computed for a 0.7 m viewing distance, 3840 px screen
## width, 0.7 m monitor width — see `FLIP.h:108`). These values shape
## the contrast-sensitivity function; the alternative would be to expose
## them through this Nim API, but for now visual-replay's framebuffers
## are all rendered to a hypothetical desktop monitor at typical viewing
## distances, so the upstream defaults apply.
##
## Reference: Andersson et al., "FLIP: A Difference Evaluator for
## Alternating Images", HPG 2020.
## https://research.nvidia.com/publication/2020-07_FLIP

{.push raises: [].}

import std/algorithm
import ./image_diff/flip_backend
import ./image_diff/png_writer

type
  FlipError* = object of CatchableError
    ## Raised when the FLIP wrapper reports a failure.

  FlipResult* = object
    ## Output of `flip()`. The error map is one float per pixel in
    ## row-major order; values are in [0, 1] where 0 means "no
    ## perceptual difference" and 1 means "as different as possible".
    errorMap*: seq[float32]
    width*, height*: int
    mean*: float32
    p50*, p90*, p99*: float32
    maxError*: float32

proc raiseFlip(msg: string) {.noinline, noreturn, raises: [FlipError].} =
  raise (ref FlipError)(msg: msg)

proc percentile(sorted: seq[float32]; q: float32): float32 =
  ## Return the q-th percentile (q in [0, 1]) of `sorted` (already
  ## ascending). Uses the lower-rank convention so e.g. p50 of a length-1
  ## sequence is just that element.
  if sorted.len == 0: return 0.0f
  var idx = int(q * float32(sorted.len - 1))
  if idx < 0: idx = 0
  if idx > sorted.high: idx = sorted.high
  result = sorted[idx]

proc flip*(reference, candidate: openArray[byte];
           width, height: int;
           channels: int = 4): FlipResult {.raises: [FlipError].} =
  ## Compute the FLIP error map between `reference` and `candidate`.
  ##
  ## Both buffers must be `width*height*channels` bytes of sRGB pixel
  ## data. `channels` must be 3 (RGB) or 4 (RGBA); alpha is ignored.
  ## Width and height must be positive.
  ##
  ## Returns a `FlipResult` whose `errorMap` is the per-pixel error in
  ## [0, 1] and whose summary fields (`mean`, `p50`, `p90`, `p99`,
  ## `maxError`) are computed from that map.
  if width <= 0 or height <= 0:
    raiseFlip("flip: width and height must be positive (got " &
              $width & "x" & $height & ")")
  if channels notin {3, 4}:
    raiseFlip("flip: channels must be 3 or 4 (got " & $channels & ")")
  let expectedLen = width * height * channels
  if reference.len != expectedLen:
    raiseFlip("flip: reference.len " & $reference.len &
              " != width*height*channels (" & $expectedLen & ")")
  if candidate.len != expectedLen:
    raiseFlip("flip: candidate.len " & $candidate.len &
              " != width*height*channels (" & $expectedLen & ")")

  let n = width * height
  var outPtr: ptr cfloat = nil
  let rc = ct_flip_compute(
    cast[ptr UncheckedArray[byte]](unsafeAddr reference[0]),
    cast[ptr UncheckedArray[byte]](unsafeAddr candidate[0]),
    cint(width), cint(height), cint(channels),
    addr outPtr)
  if rc != 0 or outPtr == nil:
    raiseFlip("ct_flip_compute failed: rc=" & $rc)

  result.width = width
  result.height = height
  result.errorMap = newSeq[float32](n)
  copyMem(addr result.errorMap[0], outPtr, n * sizeof(float32))
  ct_free(outPtr)

  # Summary statistics. Compute mean from the unsorted view first
  # (avoids paying for the sort if the caller never reads the
  # percentile fields), then sort once for the percentiles + max.
  var sum: float64 = 0.0
  for v in result.errorMap: sum += float64(v)
  result.mean = float32(sum / float64(n))

  var sorted = result.errorMap  # copy
  sorted.sort()
  result.p50 = percentile(sorted, 0.50f)
  result.p90 = percentile(sorted, 0.90f)
  result.p99 = percentile(sorted, 0.99f)
  result.maxError = sorted[sorted.high]

proc renderFlipPng*(res: FlipResult; dst: string) {.raises: [FlipError].} =
  ## Render the FLIP error map as a magma-mapped PNG at `dst`.
  ##
  ## Useful in CI: when a software-vs-hardware test fails, write the
  ## error PNG alongside both raw frames to the test output directory
  ## so a human can see exactly which region diverged.
  try:
    writeMagmaPng(res.errorMap, res.width, res.height, dst)
  except PngWriteError as e:
    raiseFlip("renderFlipPng: " & e.msg)

{.pop.}
