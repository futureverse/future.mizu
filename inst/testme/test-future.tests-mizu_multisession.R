#' @tags detritus-files
#' @tags mizu_multisession
#' @tags future.tests

if (requireNamespace("future.tests")) {
  future.tests::check("future.mizu::mizu_multisession", timeout = 30.0, exit_value = FALSE)
  gc()
}
