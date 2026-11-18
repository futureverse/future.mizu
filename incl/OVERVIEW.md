> **Note:** This package is an early prototype under development.

## Introduction

The **[future.mizu]** package is a backend for the **[future]**
framework, also known as the [Futureverse]. The Futureverse makes it
easy to parallelize existing R code - often with only a minor change
of code. Most users interact with it via higher-level packages such
as **[futurize]**, **[future.apply]**, **[furrr]**, and
**[doFuture]**, and you choose _where_ and _how_ the code runs by
setting a future backend with `plan()`. This package adds the
`mizu_multisession` backend, which runs futures in parallel on the
local machine using the **[mizu]** package.

```r
library(futurize)
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
```

The only thing that differs from using [any other future backend](https://www.futureverse.org/backends.html) is
the `plan()` call. The code does not have to change, it gives
identical results, and it behaves exactly the same.


## The mizu_multisession backend

| Backend             | Description                                                       | Alternative in future package
|:--------------------|:------------------------------------------------------------------|:------------------------------
| `mizu_multisession` | parallel evaluation in separate R processes (on current machine) | `plan(multisession)`

The **mizu** package runs parallel R workers on the local machine.
Instead of communicating via sockets, the main R process and the
workers exchange data via shared memory - POSIX shared memory on Linux
and macOS, and Win32 file mappings on Windows.


### Advantages

* Communication between the main R process and the workers is cheap,
  which means that work can be split up into many small futures
  without the overhead dominating.

* Large vectors and data frames are read by the workers in place,
  without each worker holding its own copy.

* It works on Linux, macOS, and Windows, and requires no additional
  setup.


### Limitations

* The workers always run on the local machine. For workers on other
  machines, or on a high-performance compute (HPC) cluster, use
  another future backend, e.g. `plan(cluster)` or
  **[future.batchtools]**.

* At most 64 workers are supported by **mizu**.

* Data is passed via shared memory, which is limited in size. For
  instance, Docker containers default to only 64 MB of shared memory,
  which might not be enough when passing large objects.

* Cancelling a future is advisory. A future that is already running
  on a worker cannot be interrupted; it runs to completion and its
  result is discarded.

* Using a single worker, `plan(future.mizu::mizu_multisession, workers = 1)`,
  falls back to sequential processing in the current R process, unless
  the number of workers is protected by `I()`, e.g. `workers = I(1)`.

[Futureverse]: https://www.futureverse.org
[future]: https://future.futureverse.org
[future.mizu]: https://future.mizu.futureverse.org
[future.apply]: https://future.apply.futureverse.org
[future.batchtools]: https://future.batchtools.futureverse.org
[furrr]: https://furrr.futureverse.org
[doFuture]: https://doFuture.futureverse.org
[futurize]: https://futurize.futureverse.org
[mizu]: https://cran.r-project.org/package=mizu
