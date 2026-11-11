#' A future backend based on the 'mizu' framework
#'
#' Set up the future parameters.
#'
#' @param workers The number of parallel workers (R processes) to launch,
#' or a function returning such a number. A single worker, unless
#' protected by [base::I()], falls back to sequential processing in the
#' current R process. At most 64 workers are supported by \pkg{mizu}.
#'
#' @param \ldots Additional arguments passed to [future::FutureBackend()].
#'
#' @return An object of class `MizuFutureBackend`.
#'
#' @section Limitations:
#' \pkg{mizu} workers always run on the local machine, and they communicate
#' via shared memory. Cancelling a future is advisory: a future that is
#' already running on a worker cannot be interrupted, and runs to completion
#' with its result being discarded.
#'
#' @aliases MizuFutureBackend
#' @importFrom parallelly availableCores
#' @importFrom future FutureBackend FutureError SequentialFutureBackend
#' @importFrom mizu mizu_pool
#' @export
MizuFutureBackend <- function(workers = availableCores(), ...) {
  if (is.function(workers)) workers <- workers()
  stop_if_not(is.numeric(workers))
  workers <- structure(as.integer(workers), class = class(workers))
  stop_if_not(length(workers) == 1, is.finite(workers), workers >= 1)

  ## Fall back to sequential futures if only a single additional R process
  ## can be spawned off, i.e. then use the current main R process.
  if (workers == 1L && !inherits(workers, "AsIs")) {
    ## covr: skip=1
    return(SequentialFutureBackend(...))
  }

  max_workers <- 64L
  if (workers > max_workers) {
    stop(FutureError(sprintf("The 'mizu' framework supports at most %d parallel workers, but %d were requested", max_workers, workers)))
  }

  core <- FutureBackend(
    reg = "workers-mizu",
    workers = workers,
    pool = NULL,
    ...,
    timeout = getOption("future.wait.timeout", 30 * 24 * 60 * 60),
    delta = getOption("future.wait.interval", 0.2),
    alpha = getOption("future.wait.alpha", 1.01)
  )
  core[["futureClasses"]] <- c("MizuFuture", "MultiprocessFuture", core[["futureClasses"]])
  core <- structure(core, class = c("MizuFutureBackend", "MultiprocessFutureBackend", class(core)))

  ## Launch the workers up front, to fail early
  void <- get_pool(core)

  core
}


## The pool of workers is (re)created on demand, because stopWorkers()
## stops it while the backend may still be used afterward, e.g. plan(plan())
#' @importFrom mizu mizu_pool
get_pool <- function(backend) {
  pool <- backend[["pool"]]
  if (is.null(pool)) {
    pool <- mizu_pool(n_workers = as.integer(backend[["workers"]]))
    backend[["pool"]] <- pool
  }
  pool
}


#' @importFrom mizu mizu_submit
#' @importFrom future launchFuture
#' @export
launchFuture.MizuFutureBackend <- function(backend, future, ...) {
  debug <- isTRUE(getOption("future.mizu.debug"))
  if (debug) {
    mdebugf_push("launchFuture() for %s ...", class(backend)[1])
    on.exit(mdebug_pop())
  }

  stop_if_not(nbrOfWorkers(backend) > 0L)

  ## Wait for a free worker
  waitForWorker(backend, debug = debug)

  ## Record 'backend' in future for now
  future[["backend"]] <- backend

  workers <- backend[["workers"]]
  if (!is.null(workers)) future[["workers"]] <- workers

  data <- getFutureData(future)

  future[["state"]] <- "submitted"
  ## Note, the task handle must be kept alive; an uncollected handle that
  ## is garbage collected cancels its task
  task <- mizu_submit(get_pool(backend), future:::evalFuture(data), data = data)
  future[["task"]] <- task
  future[["state"]] <- "running"

  ## Allocate future to worker
  reg <- backend[["reg"]]
  FutureRegistry(reg, action = "add", future = future, earlySignal = FALSE)

  invisible(future)
}


#' @importFrom future stopWorkers
#' @importFrom mizu mizu_pool_stop
#' @export
stopWorkers.MizuFutureBackend <- function(backend, ...) {
  debug <- isTRUE(getOption("future.mizu.debug"))
  if (debug) {
    mdebugf_push("stopWorkers() for %s ...", class(backend)[1])
    on.exit(mdebug_pop())
  }

  reg <- backend[["reg"]]
  futures <- FutureRegistry(reg, action = "list", earlySignal = FALSE)
  if (debug) mdebugf("Number of active futures: %d", length(futures))

  ## Stopping the pool cancels queued tasks and shuts down the workers
  pool <- backend[["pool"]]
  if (!is.null(pool)) {
    tryCatch({
      mizu_pool_stop(pool)
    }, error = function(e) NULL, warning = function(w) NULL)
    backend[["pool"]] <- NULL
  }

  ## Erase registry
  if (length(futures) > 0L) {
    void <- FutureRegistry(reg, action = "reset")
  }

  backend
}


#' @importFrom future nbrOfWorkers
#' @export
nbrOfWorkers.MizuFutureBackend <- function(evaluator) {
  backend <- evaluator
  as.integer(backend[["workers"]])
}


#' @importFrom future nbrOfFreeWorkers
#' @export
nbrOfFreeWorkers.MizuFutureBackend <- function(evaluator, background = FALSE, ...) {
  backend <- evaluator
  reg <- backend[["reg"]]
  workers <- backend[["workers"]]

  usedWorkers <- length(FutureRegistry(reg, action = "list", earlySignal = FALSE))
  workers <- max(0L, as.integer(workers) - usedWorkers)
  stop_if_not(length(workers) == 1L, !is.na(workers), workers >= 0L, is.finite(workers))

  workers
}


## Collect the outcome of the mizu task, without blocking if timeout = 0.
## A mizu result can only be collected once, so the outcome is stored in
## the future. Returns TRUE if the outcome is available, otherwise FALSE.
#' @importFrom mizu mizu_collect mizu_is_sentinel
mizu_collect_future <- function(future, timeout = Inf) {
  if (!is.null(future[["mizu_outcome"]])) return(TRUE)

  task <- future[["task"]]
  stop_if_not(!is.null(task))

  outcome <- tryCatch({
    list(value = mizu_collect(task, timeout = timeout))
  }, error = function(e) {
    list(error = e)
  })

  if (is.null(outcome[["error"]]) && mizu_is_sentinel(outcome[["value"]])) {
    return(FALSE)
  }

  future[["mizu_outcome"]] <- outcome
  TRUE
}


#' @importFrom future resolved run
#' @export
resolved.MizuFuture <- function(x, .signalEarly = TRUE, ...) {
  debug <- isTRUE(getOption("future.mizu.debug"))
  if (debug) {
    mdebugf_push("resolved() for %s ...", class(x)[1])
    on.exit(mdebug_pop())
  }

  resolved <- NextMethod()
  if (resolved) {
    if (debug) mdebug("already resolved")
    return(TRUE)
  }

  if (x[["state"]] == "created") { ## Not yet launched (iff lazy)
    if (debug) mdebug("just created; launching")
    x <- run(x)
    return(FALSE)
  }

  resolved <- mizu_collect_future(x, timeout = 0)

  ## Collect and relay immediateCondition if they exist
  conditions <- readImmediateConditions(signal = TRUE)
  ## Record conditions as signaled
  signaled <- c(x[[".signaledConditions"]], conditions)
  x[[".signaledConditions"]] <- signaled

  ## Signal conditions early? (happens only iff requested)
  if (resolved && .signalEarly) signalEarly(x, ...)

  resolved
}


#' @importFrom future result FutureError FutureInterruptError
#' @export
result.MizuFuture <- function(future, ...) {
  debug <- isTRUE(getOption("future.mizu.debug"))
  if (debug) {
    mdebugf_push("result() for %s ...", class(future)[1])
    mdebugf("Future state: %s", sQuote(future[["state"]]))
    on.exit(mdebug_pop())
  }

  state <- future[["state"]]
  if (state == "finished") {
    return(future[["result"]])
  } else if (state %in% c("failed", "interrupted")) {
    stop(future[["result"]])
  }

  backend <- future[["backend"]]
  reg <- backend[["reg"]]

  ## Stopping the workers may already have erased the registry
  remove_from_registry <- function() {
    if (FutureRegistry(reg, action = "contains", future = future)) {
      FutureRegistry(reg, action = "remove", future = future)
    }
  }

  ## Block until the outcome is available
  void <- mizu_collect_future(future, timeout = Inf)
  outcome <- future[["mizu_outcome"]]
  future[["mizu_outcome"]] <- NULL

  if (!is.null(outcome[["error"]])) {
    error <- outcome[["error"]]
    if (debug) mdebugf("mizu error: %s", conditionMessage(error))

    label <- sQuoteLabel(future)

    if (inherits(error, c("mizu_error_worker_died", "mizu_error_cancelled"))) {
      if (inherits(error, "mizu_error_worker_died")) {
        event <- sprintf("was terminated while %s", state)
      } else {
        event <- sprintf("was %s", if (state %in% "running") "canceled" else state)
      }
      future[["state"]] <- "interrupted"
      msg <- sprintf("Future (%s) of class %s %s, while running on localhost (%s)", label, class(future)[1], event, conditionMessage(error))
      result <- FutureInterruptError(msg, future = future)
    } else {
      future[["state"]] <- "failed"
      msg <- sprintf("Failed to retrieve results from %s (%s). The mizu framework reports: %s", class(future)[1], label, conditionMessage(error))
      result <- FutureError(msg, future = future)
    }
    if (debug) mdebug(msg)
    future[["result"]] <- result
    remove_from_registry()
    stop(result)
  }

  result <- outcome[["value"]]

  ## Collect and relay immediateCondition if they exist
  conditions <- readImmediateConditions()
  ## Record conditions as signaled
  signaled <- c(future[[".signaledConditions"]], conditions)
  future[[".signaledConditions"]] <- NULL
  if (length(signaled) > 0L) {
    result[["conditions"]] <- c(signaled, result[["conditions"]])
  }

  future[["result"]] <- result
  future[["state"]] <- "finished"
  remove_from_registry()

  result
}


#' @importFrom future interruptFuture
#' @importFrom mizu mizu_cancel
#' @export
interruptFuture.MizuFutureBackend <- function(backend, future, ...) {
  ## Cancellation is advisory; a running future runs to completion
  task <- future[["task"]]
  if (!is.null(task)) mizu_cancel(task)
  future[["state"]] <- "interrupted"
  future
}


## This function will be exported to the parallel workers. Because of this,
## it is important that its enclosure is minimal. In R, function argument
## promises retain their calling environment (which holds the 'future' object
## and globals). To avoid serializing that calling environment, we attach
## a clean environment containing only 'path' whose parent is the package namespace.
make_immediate_condition_handler <- function(path) {
  h <- function(cond) {
    fileImmediateConditionHandler(cond, path = path)
  }
  env <- new.env(parent = asNamespace("future.mizu"))
  env$path <- as.character(path)
  environment(h) <- env
  h
}

#' @exportS3Method getFutureBackendConfigs MizuFuture
getFutureBackendConfigs.MizuFuture <- function(future, ..., debug = isTRUE(getOption("future.debug"))) {
  conditionClasses <- future[["conditions"]]
  if (is.null(conditionClasses)) {
    capture <- list()
  } else {
    path <- immediateConditionsPath(rootPath = tempdir())
    capture <- list(
      immediateConditionHandlers = list(
        immediateCondition = make_immediate_condition_handler(path)
      )
    )
  }

  list(
    capture = capture
  )
}


#' @importFrom future tweak
#' @export
tweak.mizu_multisession <- function(strategy, ..., penvir = parent.frame()) {
  attr(strategy, "init") <- TRUE
  backend <- attr(strategy, "backend", exact = TRUE)
  if (!is.null(backend)) {
    stopWorkers(backend)
    attr(strategy, "backend") <- NULL
  }
  NextMethod("tweak")
}


#' Mizu-based localhost multisession futures
#'
#' _WARNING: This function must never be called.
#'  It may only be used with [future::plan()]_
#'
#' @inheritParams future::Future
#' @inheritParams future::multisession
#'
#' @param \ldots Not used.
#'
#' @return Nothing.
#'
#' @example incl/mizu_multisession.R
#'
#' @importFrom parallelly availableCores
#' @importFrom future future
#' @export
mizu_multisession <- function(..., workers = availableCores(), envir = parent.frame()) {
  stop("INTERNAL ERROR: The future.mizu::mizu_multisession() function must never be called directly")
}
class(mizu_multisession) <- c("mizu_multisession", "mizu", "multiprocess", "future", "function")
attr(mizu_multisession, "init") <- TRUE
attr(mizu_multisession, "factory") <- MizuFutureBackend
