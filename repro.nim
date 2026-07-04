## Reprobuild project file for codetracer-image-diff.
##
## **Typed-Cross-Project-Deps rollout, Wave-0 leaf.** ``codetracer-image-diff``
## is a pure-Nim leaf library — a perceptual image-diff (NVIDIA FLIP CPU
## build) for CodeTracer visual-replay's software-vs-hardware tests. Its
## importable surface (``src/image_diff.nim`` + ``src/image_diff/*``) wraps a
## VENDORED C++ backend (NVIDIA FLIP's single-header ``vendor/flip/FLIP.h`` and
## Sean Barrett's ``vendor/stb/stb_image_write.h``), pulled in at compile time
## via ``{.compile: "src/flip_wrapper.cpp".}`` / ``{.emit.}`` from the FFI
## layer. It has NO in-scope sibling workspace dependency: the nimble file only
## ``requires "nim >= 2.2.0"``, every importable module lives under this repo's
## ``src/`` tree, and the two external C/C++ dependencies (FLIP, stb) are
## vendored, not workspace repos. So the ``uses:`` block is just the toolchain
## floor and there is no ``uses: "<sibling>"`` edge.
##
## A Mode 1 / Mode 3 hybrid (per
## ``an internal design document``) modelled on the
## canonical ``runquota/repro.nim`` / ``nim-stackable-hooks/repro.nim`` /
## ``nim-libvterm/repro.nim`` / ``nim-pty/repro.nim`` leaf recipes:
##
## * Declares the upstream tool floor via ``uses:`` so consumers that depend
##   on this repo (via ``uses: "image_diff"``) pick up the same toolchain the
##   nimble file's ``requires "nim >= 2.2.0"`` implies.
## * Declares ``library image_diff`` so consumers can express a workspace
##   dependency on this repo. The importable umbrella is ``src/image_diff.nim``
##   (consumers ``import image_diff`` for the public ``flip(...)`` /
##   ``renderFlipPng(...)`` API); the internal FFI/PNG submodules under
##   ``src/image_diff/`` are pulled in transitively and are not part of the
##   public surface.
## * Emits, per test file under ``tests/``, a BUILD edge
##   (``buildNimUnittest.build``) that compiles ``build/test-bin/<stem>`` and
##   an EXECUTE edge (``edge.testBinary.run``) that runs it — the two-edge test
##   template from ``an internal design document`` §"The test template".
##   BUILD halves collect into ``test-builds``; EXECUTE halves collect into
##   ``test`` so ``repro build test`` / ``repro test`` materialise the runnable
##   closure (each execute edge transitively depends on its build edge).
##
## **Module search path + backend + compile flags.** codetracer-image-diff
## ships no ``config.nims`` / ``nim.cfg``; its ``Justfile`` / nimble ``test``
## task supply ``-p:src`` (``--path:src``) and ``-d:release`` on every compile.
## Each BUILD edge threads ``paths = @["src"]`` (load-bearing — ``import
## ../src/image_diff`` resolves from the compiled file's own relative import,
## but the transitive ``src/image_diff/flip_backend`` / ``png_writer`` FFI
## modules ``currentSourcePath()``-anchor the vendored include dirs, so the
## repo's own ``-p:src`` is reproduced here for parity) and
## ``defines = @["release"]`` (mirrors the nimble ``test`` task's
## ``nim cpp -d:release -p:src``).
##
## **C++-vendored backend under the C backend.** The nimble file sets
## ``backend = "cpp"`` and the ``Justfile`` / nimble ``test`` task use
## ``nim cpp``. ``buildNimUnittest.build`` always emits ``nim c`` (the C
## backend); that is CORRECT here and produces an identical passing binary,
## because the C++ dependency is confined to the ``{.compile.}``d
## ``flip_wrapper.cpp`` and the ``{.emit.}``d ``stb_image_write.h`` — both are
## ``.cpp``/C++-source translation units that ``nim c`` hands to the C++
## compiler by file extension, and ``flip_backend.nim`` already carries the
## explicit ``{.passL: "-lstdc++".}`` that links the C++ runtime. So the
## generated-Nim TU compiling as C rather than C++ makes no difference: the
## FLIP/stb C++ TUs still compile with ``g++`` and the binary links + runs to
## exit 0. (Verified: all four tests compile with ``nim c … --path:src`` and
## run to exit 0 on this Linux host.) No ``cpp``-backend subcommand is needed;
## the ``buildNimUnittest`` ``nim c`` surface suffices.
##
## **Per-test platform gating.** Every test file under ``tests/`` is fully
## portable — NONE carries a ``{.error.}`` module guard, an OS-only ``import``,
## or a ``when defined(<os>): quit`` head-guard. Re-deriving from each file's
## imports + body:
##
##   * ``test_flip_identical`` / ``test_flip_different`` / ``test_flip_subpixel``
##     — ``import std/[strformat]`` + ``../src/image_diff``; build the pixel
##     buffers in pure Nim, call ``flip(...)``, ``doAssert`` on the summary
##     stats. No OS conditional anywhere. Run to exit 0 on every host.
##   * ``test_flip_png`` — ``import std/[os, strformat, strutils]`` +
##     ``../src/image_diff``; the ``std/os`` use is portable (``createDir`` /
##     ``fileExists`` / ``getFileInfo`` on ``tests/output/``), not an OS gate.
##     Runs to exit 0 on every host.
##
## So there are no ``when defined(...)`` extraction gates: the whole corpus is
## portable-and-runnable here and every edge is unconditionally in the graph.
## This mirrors what the repo's own ``nimble test`` runs — exactly these four
## files, in this order.
##
## **No pool.** Unlike nim-pty, these tests spawn no ptys/subprocesses and hold
## no shared external resource: each is a self-contained in-process FLIP
## computation over an in-memory pixel buffer (``test_flip_png`` additionally
## writes one PNG into its OWN ``tests/output/`` dir). They are safe to run
## fully in parallel, so no ``buildPool`` / ``pool =`` serialisation is used.
##
## **Tool provisioning.** ``defaultToolProvisioning "path"`` matches the
## canonical recipes: the nix dev shell puts ``nim`` + ``gcc`` (the C/C++
## back-end ``nim`` shells out to) on ``PATH``, so the weak-local PATH resolver
## is the right default. Without it ``repro build`` refuses to run with "typed
## tool provisioning is required for uses declarations".

import repro_project_dsl

# ``ct_test_nim_unittest`` supplies the ``buildNimUnittest.build(...)``
# typed-tool used by every test BUILD edge and the ``edge.testBinary.run(...)``
# UFCS dispatch for the EXECUTE edges. It re-exports ``repro_project_dsl`` so
# the import order is unimportant. Like the ``nim-stackable-hooks`` /
# ``nim-libvterm`` / ``nim-pty`` leaf recipes, this file does NOT import
# ``ct_test_runner_install`` (engine-coupled, reprobuild-internal): the execute
# edges route through the engine's default direct-binary runner (run the
# binary, key on exit status), which is exactly the exit-0 verification this
# corpus needs — each test is a plain ``doAssert`` script that ``echo``s
# ``PASSED`` and exits non-zero on any failed assertion.
import ct_test_nim_unittest

type
  ImageDiffTestSpec = object
    ## One entry per test file. ``source`` is the repo-relative ``.nim``
    ## path; ``binary`` is the ``build/test-bin/<stem>`` output.
    source: string
    binary: string

# The corpus — one entry per ``tests/test_*.nim`` standalone test file, in the
# same order the nimble ``test`` task runs them. Every entry compiles + runs to
# exit 0 on every host (see the module docstring's platform-gating note), so
# there is a single unconditional list — no per-OS partition.
const imageDiffTestSpecs: seq[ImageDiffTestSpec] = @[
  ImageDiffTestSpec(source: "tests/test_flip_identical.nim",
    binary: "build/test-bin/test_flip_identical"),
  ImageDiffTestSpec(source: "tests/test_flip_different.nim",
    binary: "build/test-bin/test_flip_different"),
  ImageDiffTestSpec(source: "tests/test_flip_subpixel.nim",
    binary: "build/test-bin/test_flip_subpixel"),
  ImageDiffTestSpec(source: "tests/test_flip_png.nim",
    binary: "build/test-bin/test_flip_png"),
]

package image_diff:
  defaultToolProvisioning "path"

  uses:
    # Toolchain floor — the PATH-resolvable binaries the build needs. ``nim``
    # compiles every test binary (the ``buildNimUnittest.build`` edges below,
    # matching the nimble file's ``requires "nim >= 2.2.0"``); ``gcc`` is the
    # C/C++ back-end ``nim`` shells out to — it compiles the generated Nim TU,
    # the ``{.compile.}``d ``flip_wrapper.cpp`` and the ``{.emit.}``d
    # ``stb_image_write.h`` (both via the C++ front-end by file extension), and
    # links the ``-lstdc++`` runtime. Sufficient for the path-mode resolver
    # under ``nix develop``.
    "nim >=2.2 <3.0"
    "gcc >=12"

  # Library declaration — the ``src/`` tree the tests put on ``--path`` is
  # importable when this package is consumed via ``uses: "image_diff"``. The
  # umbrella is ``src/image_diff.nim`` (the public ``flip(...)`` /
  # ``renderFlipPng(...)`` API); the internal ``src/image_diff/`` FFI + PNG
  # submodules are transitive.
  library image_diff

  build:
    # Two-edge test template (Package-Model.md §"The test template"): one
    # compile BUILD edge + one EXECUTE edge per test file. BUILD halves collect
    # into ``test-builds`` (compile-only verification); EXECUTE halves collect
    # into ``test`` so ``repro test`` / ``repro build test`` materialise the
    # runnable closure (each execute edge transitively depends on its build
    # edge).
    #
    # Compile flags reproduce the repo's ``nimble test`` invocation
    # (``nim cpp -d:release -p:src``):
    #   * ``paths = @["src"]``       — ``--path:src`` (no ``config.nims`` in the
    #     repo; the ``Justfile`` / nimble task supply it).
    #   * ``defines = @["release"]`` — ``-d:release``.
    #   * ``extraInputs = @["src"]`` — declare the whole backend + vendored
    #     headers tree as an input of every compile so an edit to
    #     ``flip_wrapper.cpp`` / ``FLIP.h`` / ``stb_image_write.h`` (reached via
    #     the ``{.compile.}`` / ``{.emit.}`` include roots, which the Nim
    #     automatic-monitor also captures) reliably invalidates the binary.
    #   * ``--mm:`` is left at Nim 2.2's per-file default (the repo pins no
    #     memory manager for its default test point — the nimble ``test`` task
    #     passes only ``-d:release -p:src``), and ``--threads:on`` rides in via
    #     the wrapper's default.
    var testBuildActions: seq[BuildActionDef] = @[]
    var testExecuteActions: seq[BuildActionDef] = @[]

    proc emitTestPair(source, binary: string;
                      buildActions, executeActions: var seq[BuildActionDef]) =
      var lastSlash = -1
      for i in 0 ..< binary.len:
        if binary[i] == '/' or binary[i] == '\\':
          lastSlash = i
      let stem =
        if lastSlash >= 0: binary[lastSlash + 1 .. ^1]
        else: binary
      let edge = buildNimUnittest.build(
        source = source,
        binary = binary,
        defines = @["release"],
        paths = @["src"],
        extraInputs = @["src"],
        actionId = "image_diff.test_build." & stem)
      buildActions.add(edge.action)
      # ``registerImplicitName = false`` because the BUILD edge already owns
      # the binary basename as the implicit target name; the explicit
      # ``actionId`` is the execute edge's selector (two-edge shape mirroring
      # reprobuild's ``repro.nim`` / the sibling leaf recipes).
      let executeEdge = edge.testBinary.run(
        actionId = "image_diff.test_execute." & stem,
        registerImplicitName = false)
      executeActions.add(executeEdge)

    for spec in imageDiffTestSpecs:
      emitTestPair(spec.source, spec.binary,
        testBuildActions, testExecuteActions)

    discard collect("test", testExecuteActions)
    discard collect("test-builds", testBuildActions)
