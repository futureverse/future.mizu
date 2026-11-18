# future.mizu: Parallel Future Backend using 'mizu'

The future.mizu package implements the Future API using the mizu
package, which runs parallel R workers on the local machine
communicating via shared memory.

## See also

Useful links:

- <https://github.com/futureverse/future.mizu>

- Report bugs at <https://github.com/futureverse/future.mizu/issues>

## Author

**Maintainer**: Henrik Bengtsson <henrikb@braju.com>
([ORCID](https://orcid.org/0000-0002-7579-5165)) \[copyright holder\]

Authors:

- Henrik Bengtsson <henrikb@braju.com>
  ([ORCID](https://orcid.org/0000-0002-7579-5165)) \[copyright holder\]

## Examples

``` r
library(future)
plan(future.mizu::mizu_multisession)

# A function that returns a future
# (note that N is a global variable)
f <- function() future({
  4 * sum((runif(N) ^ 2 + runif(N) ^ 2) < 1) / N
}, seed = TRUE)

# Run a simple sampling approximation of pi in parallel using  M * N points:
N <- 1e6  # samples per worker
M <- 10   # iterations
pi_est <- Reduce(sum, Map(value, replicate(M, f()))) / M
print(pi_est)
#> [1] 3.141674

## Switch back to sequential processing, which also
## shuts down the automatically launched mizu workers 
plan(sequential)
```
