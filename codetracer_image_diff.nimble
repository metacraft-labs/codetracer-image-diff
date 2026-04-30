# Package
version       = "0.1.0"
author        = "Metacraft Labs"
description   = "Perceptual image-diff for CodeTracer visual-replay tests (NVIDIA FLIP CPU build)"
license       = "BSD-3-Clause"
srcDir        = "src"
backend       = "cpp"

# Dependencies
requires "nim >= 2.2.0"

task test, "Run all tests":
  exec "nim cpp -d:release -p:src -r tests/test_flip_identical.nim"
  exec "nim cpp -d:release -p:src -r tests/test_flip_different.nim"
  exec "nim cpp -d:release -p:src -r tests/test_flip_subpixel.nim"
  exec "nim cpp -d:release -p:src -r tests/test_flip_png.nim"
