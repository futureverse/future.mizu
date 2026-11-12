#' @tags mizu_multisession
library(future)
library(future.mizu)

message("*** MizuFutureBackend ...")

plan(mizu_multisession, workers = 2L)
stopifnot(nbrOfWorkers() == 2L)

## Futures run in other processes
f <- future(Sys.getpid())
stopifnot(value(f) != Sys.getpid())

## Globals and errors
x <- 1:3
stopifnot(identical(value(future(sum(x))), 6L))
f <- future(stop("boom"))
res <- tryCatch(value(f), error = identity)
stopifnot(inherits(res, "error"), conditionMessage(res) == "boom")

## Lazy futures and resolved()
f <- future(42, lazy = TRUE)
while (!resolved(f)) Sys.sleep(0.05)
stopifnot(value(f) == 42)

## More futures than workers
fs <- lapply(1:6, function(i) future(i))
stopifnot(identical(unlist(value(fs)), 1:6))

## Immediate conditions
f <- future({ message("hello"); 1 })
msgs <- character()
v <- withCallingHandlers(value(f), message = function(m) {
  msgs <<- c(msgs, conditionMessage(m))
  invokeRestart("muffleMessage")
})
stopifnot(v == 1, identical(msgs, "hello\n"))

## Worker termination
## (tools::pskill() with SIGKILL does not terminate the process on Windows)
f <- future({
  if (.Platform$OS.type == "windows") {
    quit(save = "no", status = 1L, runLast = FALSE)
  } else {
    tools::pskill(Sys.getpid(), tools::SIGKILL)
  }
  1
})
res <- tryCatch(value(f), error = identity)
if (!inherits(res, "FutureInterruptError")) {
  ## Help to troubleshoot platform-specific outcomes
  message("Unexpected outcome of future whose worker was terminated:")
  message("Classes: ", paste(sQuote(class(res)), collapse = ", "))
  if (inherits(res, "condition")) {
    message("Message: ", conditionMessage(res))
  } else {
    str(res)
  }
}
stopifnot(inherits(res, "FutureInterruptError"))

## A single worker falls back to sequential processing
plan(mizu_multisession, workers = 1L)
stopifnot(value(future(Sys.getpid())) == Sys.getpid())

plan(sequential)

## On macOS, 'mizu' leaves its 'mizu' folder behind in the temporary
## directory when a worker was killed, which 'R CMD check' reports as
## detritus. Remove it, but only under 'R CMD check' where TMPDIR is private
if (Sys.info()[["sysname"]] == "Darwin" && nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_"))) {
  unlink(file.path(dirname(tempdir()), "mizu"), recursive = TRUE)
}

message("*** MizuFutureBackend ... DONE")
