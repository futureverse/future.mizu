# Version (development version)

## Bug Fixes

 * Calling `value()` or `result()` on a `MizuFuture` that had already
   been collected and then canceled with `cancel()` failed with
   `mizu: task handle already collected`, instead of returning the
   cached result (so `value()` can signal a `FutureCanceledError`).


# Version 0.1.0 [2026-11-23]

 * Released on R-universe. The future backend is fully compliant with
   the Future API.


# Version 0.0.1 [2026-11-09]

 * Initial version. Implements the `mizu_multisession` future backend,
   which runs futures in parallel R workers on the local machine using
   the **mizu** package.
