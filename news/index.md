# Changelog

## Version (development version)

### Bug Fixes

- [`listFutures()`](https://future.futureverse.org/reference/FutureBackend-class.html)
  did not list the active futures of the backend.

## Version 0.0.1

- Initial version. Implements the `mizu_multisession` future backend,
  which runs futures in parallel R workers on the local machine using
  the **mizu** package.
