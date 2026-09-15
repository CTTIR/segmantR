# Thin wrapper: the application is built by segmantR::sg_app() from package
# code. Objects pre-loaded through sg_run_app() are picked up from the legacy
# option for compatibility with direct shiny::runApp() launches.
env <- getOption("segmantR.app_env")
segmantR::sg_app(
  input = if (is.null(env)) NULL else list(image = env$image, mask = env$mask)
)
