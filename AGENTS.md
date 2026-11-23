# Working on coalton-geometry

- This is an independent mathematical library. No application's procedures, tolerances, units or conventions apply, and none goes in.
- Read README.md and ROADMAP.md before anything else: the library is reserved, and the roadmap says what is waited for before a first module. Read docs/design.md before proposing an interface: data and results in caller-owned arrays, batched calls, analytic derivatives, a branch or a missing derivative reported by name, no tolerance or application convention chosen here.
- Inspect current Git state before editing. Preserve other people's work.
- Keep mathematical algorithms in Coalton. Common Lisp handles hosting and tests; Python is for independent references and tooling.
- Clean room, in the sense docs/provenance.md gives it: a published method may be implemented from its description, and pseudocode may be read to learn the method, but the implementation is written from the mathematics in this library's own structure, never transliterated. Never read another implementation's code, whatever its licence, a consumer's own included. Record each method's source exactly, and the form read, in docs/provenance.md before the code lands. If the only source you have for a method is code, say so and stop.
- It may depend on coalton-linalg; coalton-linalg never depends on it. Keep the main ASDF system free of test, benchmark, Python and application dependencies.
- No empty package and no speculative abstraction. A module is added when a concrete use needs it, with its contract, its tests and its record together.
- Document types, storage, ownership, mutation, numerical assumptions, refusals and complexity with each public interface. Do not silently add a tolerance, a rounding or a fallback.
- Ask the four questions in CONTRIBUTING.md of every numeric routine: an intermediate that leaves the range, two arguments that are one array, work for a step not taken, anything allocated or written before a refusal. A new exported call fails the aliasing and scale-sweep rosters until it has an entry; add the entry, do not exempt it for convenience.
- Test through the public interface and against an independent reference, exact rational arithmetic where the question allows. For a regression, watch its test fail without the fix. Plant defects in the source and confirm the tests catch them; a plant counts only if the planted source compiled.
- Run scripts/check.ps1 serially at safety 1, then safety 0. Use the configured toolchain; do not install dependencies without authorization.
- Keep generated files under build/, local machine paths in ignored config.local.psd1, and recorded results distinct from current measurements.
- Scope present portability to 64-bit SBCL. Measure before making an allocation or speed claim.
- MIT-licensed. Commits carry no personal address, machine path or application name.
