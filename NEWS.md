# Version (development version)

## Miscellaneous

 * Debug output is now controlled by R option `future.debug`, or
   environment variable `R_FUTURE_DEBUG`, as for other future
   backends. R option `future.mizu.debug` and environment variable
   `R_FUTURE_MIZU_DEBUG` are no longer used.

## Bug Fixes

 * `listFutures()` did not list the active futures of the backend.


# Version 0.0.1 [2026-11-09]

 * Initial version. Implements the `mizu_multisession` future backend,
   which runs futures in parallel R workers on the local machine using
   the **mizu** package.
