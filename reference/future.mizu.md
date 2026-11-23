# future.mizu: Parallel Future Backend using 'mizu'

The future.mizu package implements the Future API using the mizu
package, which runs parallel R workers on the local machine
communicating via shared memory. The Future API is defined by the future
package.

## Details

To use mizu futures, attach future, and select the type of future you
wish to use, e.g. `plan(future.mizu::mizu_multisession)`.

## Example

    library(futurize)                     # also attaches 'future'
    plan(future.mizu::mizu_multisession)  # parallelize on the current machine

    # A slow function
    slow_fcn <- function(x) {
      Sys.sleep(1.0)
      x^2
    }

    # Example data
    xs <- 1:10

    # Sequential and parallel base R apply
    ys <- lapply(xs, slow_fcn)
    ys <- lapply(xs, slow_fcn) |> futurize()

    # Sequential and parallel purrr map
    library(purrr)
    ys <- xs |> map(slow_fcn)
    ys <- xs |> map(slow_fcn) |> futurize()

    # Sequential and parallel foreach calls
    library(foreach)
    ys <- foreach(x = xs) %do% slow_fcn(x)
    ys <- foreach(x = xs) %do% slow_fcn(x) |> futurize()

## See also

Useful links:

- <https://future.mizu.futureverse.org/>

- Report bugs at <https://github.com/futureverse/future.mizu/issues>

## Author

**Maintainer**: Henrik Bengtsson <henrikb@braju.com>
([ORCID](https://orcid.org/0000-0002-7579-5165)) \[copyright holder\]

Authors:

- Henrik Bengtsson <henrikb@braju.com>
  ([ORCID](https://orcid.org/0000-0002-7579-5165)) \[copyright holder\]
