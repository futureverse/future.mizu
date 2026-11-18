# A future backend based on the 'mizu' framework

Set up the future parameters.

## Usage

``` r
MizuFutureBackend(workers = availableCores(), ...)
```

## Arguments

- workers:

  The number of parallel workers (R processes) to launch, or a function
  returning such a number. A single worker, unless protected by
  [`base::I()`](https://rdrr.io/r/base/AsIs.html), falls back to
  sequential processing in the current R process. At most 64 workers are
  supported by mizu.

- ...:

  Additional arguments passed to
  [`future::FutureBackend()`](https://future.futureverse.org/reference/FutureBackend-class.html).

## Value

An object of class `MizuFutureBackend`.

## Limitations

mizu workers always run on the local machine, and they communicate via
shared memory. Cancelling a future is advisory: a future that is already
running on a worker cannot be interrupted, and runs to completion with
its result being discarded.
