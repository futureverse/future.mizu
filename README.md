# future.mizu: Parallel Future Backend using 'mizu'

> **Note:** This package is an early prototype under development.

## Introduction

The **[future]** package provides a generic API for using futures in
R.  A future is a simple yet powerful mechanism to evaluate an R
expression and retrieve its value at some point in time.  Futures can
be resolved in many different ways depending on which strategy is
used.  There are various types of synchronous and asynchronous futures
to choose from in the **[future]** package.

This package, **[future.mizu]**, provides a type of futures that
utilizes the **[mizu]** package.

For example,

```r
library(future)
plan(future.mizu::mizu_multisession)

x %<-% { Sys.sleep(5); 3.14 }
y %<-% { Sys.sleep(5); 2.71 }
x + y
#> [1] 5.85
```

This is obviously a toy example to illustrate what futures look like
and how to work with them.  For further examples on how to use
futures, see the vignettes of the **[future]** package as well as
those of **[future.apply]**, **[furrr]**, and **[doFuture]**.  You can
also use **[futurize]** to parallelize your existing map-reduce code,
e.g. `lapply(xs, fcn) |> futurize()`.


## Using the future.mizu backend

The **future.mizu** package implements a **future** backend wrapper
for **mizu**.


| Backend             | Description                                                      | Alternative in future package
|:--------------------|:-----------------------------------------------------------------|:------------------------------
| `mizu_multisession` | parallel evaluation in separate R processes (on current machine) | `plan(multisession)`


### Advantages of mizu futures

The **mizu** package runs parallel R workers on the local machine,
where the main R process and the workers communicate via shared memory
(POSIX shared memory on Linux and macOS, and Win32 file mappings on
Windows) instead of through sockets.  Communication is cheap enough
that work can be divided into small pieces, and large vectors and data
frames can be read in place, without being copied.  The `mizu_multisession`
futures make these properties available to everything that is built on
the Future API, e.g. **future.apply**, **furrr**, **doFuture**, and
**futurize**, without having to change any code.

Because of this, `mizu_multisession` futures behave like any other
future: the code does not have to change, the results are identical,
and output and conditions, e.g. `cat()`, `message()`, and `warning()`,
are relayed to the main R session as usual.


### Limitations

* The workers always run on the local machine.  For workers on other
  machines, or on a high-performance compute (HPC) cluster, use another
  **future** backend.

* At most 64 workers are supported by **mizu**.

* Cancelling a future is advisory.  A future that is already running on
  a worker cannot be interrupted; it runs to completion and its result
  is discarded.

* Using a single worker, `plan(future.mizu::mizu_multisession, workers = 1)`,
  falls back to sequential processing in the current R process, unless
  the number of workers is protected by `I()`, e.g. `workers = I(1)`.


## Demos

The **[future]** package provides a demo using futures for calculating
a set of Mandelbrot planes.  The demo does not assume anything about
what type of futures are used.  _The user has full control of how
futures are evaluated_.  For instance, to use `mizu_multisession`
futures, run the demo as:

```r
library(future)
plan(future.mizu::mizu_multisession)

demo("mandelbrot", package = "future", ask = FALSE)
```


[mizu]: https://cran.r-project.org/package=mizu
[future]: https://cran.r-project.org/package=future
[future.mizu]: https://github.com/futureverse/future.mizu
[future.apply]: https://cran.r-project.org/package=future.apply
[furrr]: https://cran.r-project.org/package=furrr
[doFuture]: https://cran.r-project.org/package=doFuture
[futurize]: https://cran.r-project.org/package=futurize


## Installation

The package is not yet available on CRAN.  To install the development
version from GitHub, use:

```r
remotes::install_github("futureverse/future.mizu")
```

This will install the package from source.
