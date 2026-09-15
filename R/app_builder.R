# Testable Shiny application builder

#' Build the segmantR Shiny application
#'
#' Returns a `shiny.appobj` built from package code, with explicit input
#' objects instead of global options. The app offers image/channel/band
#' selection, a protocol picker with a parameter form generated from the
#' protocol registry, mask overlay, backend status for optional DNN
#' protocols, a staged/reviewed workflow with explicit overwrite
#' confirmation, and export of a neutral interchange bundle. There is no
#' code entry of any kind.
#'
#' @param input `NULL`, an `sg_image`, an `sg_mask`, a list with `image`
#'   and/or `mask`, or the path of an interchange bundle (imported as staged).
#' @param state Optional list with initial `protocol` (id) and `parameters`
#'   (named list of overrides).
#' @param control `"off"`. The local control service
#'   (`segmantR-control-v1`) is planned and not implemented; other values
#'   signal an `sg_capability_error`.
#' @param ... Options: `read_only` (logical, disables running and review).
#'
#' @return A `shiny.appobj`.
#' @seealso [sg_run_app()], [sg_control_capabilities()]
#' @export
#' @examples
#' app <- sg_app(list(image = sg_example_image("fluorescence_nuclei")))
#' class(app)
#' \dontrun{
#' shiny::runApp(app)
#' }
sg_app <- function(input = NULL, state = NULL, control = "off", ...) {
  opts <- list(...)
  unknown <- setdiff(names(opts), "read_only")
  if (length(unknown)) {
    .sg_abort("Unknown app option{?s} {.val {unknown}}.",
              code = "UNKNOWN_PARAMETER")
  }
  if (!identical(control, "off")) {
    .sg_abort(
      c("The segmantR control service is planned but not implemented.",
        "i" = "Use {.code control = \"off\"}; see {.fn sg_control_capabilities}."),
      class = "sg_capability_error", code = "CAPABILITY_UNAVAILABLE"
    )
  }
  initial <- .sg_app_initial(input)
  protos <- sg_protocol_list()
  protos <- protos[protos$family != "postprocess" &
                     protos$id != "propagate.voronoi.v1", , drop = FALSE]
  default_protocol <- state$protocol %||% "threshold.otsu.v1"
  if (!default_protocol %in% protos$id) {
    .sg_abort("Initial protocol {.val {default_protocol}} is not available in the app.",
              code = "PROTOCOL_NOT_FOUND", class = "sg_protocol_error")
  }
  read_only <- isTRUE(opts$read_only)
  choices <- stats::setNames(
    protos$id,
    paste0(protos$title, ifelse(protos$status == "optional",
                                " (optional backend)", ""))
  )
  ui <- shiny::fluidPage(
    shiny::titlePanel("segmantR"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::h4("Data"),
        shiny::selectInput("example", "Example dataset",
                           choices = c("fluorescence_nuclei", "he_breast",
                                       "multiplex_4ch")),
        shiny::actionButton("load_example", "Load example"),
        shiny::uiOutput("channel_ui"),
        shiny::hr(),
        shiny::h4("Protocol"),
        shiny::selectInput("protocol", "Segmentation protocol",
                           choices = choices, selected = default_protocol),
        shiny::textOutput("backend_status"),
        shiny::uiOutput("parameter_ui"),
        shiny::actionButton("run", "Run protocol",
                            class = if (read_only) "disabled" else NULL),
        shiny::hr(),
        shiny::h4("Review"),
        shiny::textOutput("review_status"),
        shiny::actionButton("accept", "Mark candidate as reviewed"),
        shiny::checkboxInput("confirm_overwrite",
                             "Replace the reviewed mask (explicit overwrite)",
                             value = FALSE),
        shiny::actionButton("discard", "Discard candidate"),
        shiny::hr(),
        shiny::downloadButton("export", "Export interchange bundle (.zip)")
      ),
      shiny::mainPanel(
        shiny::plotOutput("overlay", height = "420px"),
        shiny::verbatimTextOutput("message"),
        shiny::tableOutput("measurements")
      )
    )
  )
  server <- function(input, output, session) {
    rv <- shiny::reactiveValues(
      image = initial$image,
      candidate = initial$candidate,
      reviewed = initial$reviewed,
      run = NULL,
      message = initial$message %||% "Ready."
    )
    set_message <- function(txt) rv$message <- txt
    run_guarded <- function(expr) {
      tryCatch(expr, sg_error = function(e) {
        set_message(paste0("[", e$code %||% "ERROR", "] ",
                           cli::ansi_strip(conditionMessage(e))))
        NULL
      })
    }

    shiny::observeEvent(input$load_example, {
      rv$image <- sg_example_image(input$example)
      rv$candidate <- NULL
      rv$reviewed <- NULL
      rv$run <- NULL
      set_message(paste("Loaded example", input$example))
    })

    output$channel_ui <- shiny::renderUI({
      img <- rv$image
      if (is.null(img)) return(shiny::helpText("No image loaded."))
      ch <- img$channels
      bands <- img$bands
      items <- list(shiny::selectInput(
        "channel", "Channel / band",
        choices = stats::setNames(seq_along(ch), ch), selected = 1L
      ))
      if (!is.null(bands) && any(!is.na(bands$wavelength_nm))) {
        items <- c(items, list(
          shiny::selectInput("band_operation", "Band operation",
                             choices = .sg_band_operations),
          shiny::numericInput("band_a_nm", "Band a (nm)", NA),
          shiny::numericInput("band_b_nm", "Band b (nm)", NA)
        ))
      }
      do.call(shiny::tagList, items)
    })

    output$parameter_ui <- shiny::renderUI({
      shiny::req(input$protocol)
      spec <- sg_protocol_schema(input$protocol)
      spec <- spec[!spec$name %in% .sg_selection_params, , drop = FALSE]
      overrides <- if (identical(input$protocol, default_protocol))
        state$parameters %||% list() else list()
      widgets <- lapply(seq_len(nrow(spec)), function(i) {
        .sg_param_widget(spec[i, ], overrides[[spec$name[i]]])
      })
      do.call(shiny::tagList, widgets)
    })

    output$backend_status <- shiny::renderText({
      shiny::req(input$protocol)
      p <- sg_protocol_get(input$protocol)
      if (!isTRUE(p$runtime_profile$requires_python)) {
        return("Backend: segmantR core (no Python required).")
      }
      paste0("Backend: ", p$method$backend,
             " - checked when the protocol runs. ",
             p$runtime_profile$install_hint %||% "")
    })

    collect_params <- function() {
      spec <- sg_protocol_schema(input$protocol)
      spec <- spec[!spec$name %in% .sg_selection_params, , drop = FALSE]
      out <- list()
      for (i in seq_len(nrow(spec))) {
        nm <- spec$name[i]
        val <- input[[paste0("param_", nm)]]
        if (is.null(val)) next
        if (spec$type[i] %in% c("integer", "number")) {
          if (is.na(val)) {
            if (spec$nullable[i]) out[nm] <- list(NULL)
            next
          }
          val <- if (spec$type[i] == "integer") as.integer(val) else
            as.numeric(val)
          if (length(spec$enum[[i]])) val <- as.integer(val)
        } else if (spec$type[i] == "string") {
          if (!nzchar(val)) {
            if (spec$nullable[i]) out[nm] <- list(NULL)
            next
          }
        }
        out[nm] <- list(val)
      }
      p <- sg_protocol_get(input$protocol)
      pnames <- names(p$parameters)
      if (!is.null(input$channel) && "channel" %in% pnames) {
        out$channel <- as.integer(input$channel)
      }
      if (!is.null(input$band_operation) &&
          !identical(input$band_operation, "none") &&
          "band_operation" %in% pnames) {
        out$channel <- NULL
        out$band_operation <- input$band_operation
        out$band_a_nm <- input$band_a_nm
        out$band_b_nm <- input$band_b_nm
      }
      out
    }

    shiny::observeEvent(input$run, {
      if (read_only) {
        set_message("The app is read-only.")
        return()
      }
      if (is.null(rv$image)) {
        set_message("Load an image first.")
        return()
      }
      params <- collect_params()
      run <- run_guarded(do.call(sg_protocol_run, c(
        list(image = rv$image, protocol = input$protocol), params,
        list(output = "run")
      )))
      if (is.null(run)) return()
      rv$run <- run
      if (!identical(run$record$status, "succeeded")) {
        set_message(paste0("Run ", run$record$status, ": ",
                           run$record$error$message %||% ""))
        return()
      }
      cand <- run$mask
      if (.sg_review(cand)$status == "draft") {
        cand <- sg_stage_mask(cand, source = paste(input$protocol, "app run"))
      }
      rv$candidate <- cand
      set_message(sprintf("%s: %d object(s) staged for review (revision %s).",
                          input$protocol, run$record$outputs$mask$label_count,
                          substr(run$record$outputs$mask$revision, 1, 19)))
    })

    shiny::observeEvent(input$accept, {
      if (read_only) {
        set_message("The app is read-only.")
        return()
      }
      cand <- rv$candidate
      if (is.null(cand)) {
        set_message("There is no staged candidate.")
        return()
      }
      res <- run_guarded({
        base <- if (is.null(rv$reviewed)) {
          cand
        } else {
          sg_replace_mask(rv$reviewed, cand,
                          expected_revision = sg_mask_revision(rv$reviewed),
                          overwrite = isTRUE(input$confirm_overwrite))
        }
        sg_review_mask(base, reviewer = "app",
                       expected_revision = sg_mask_revision(base))
      })
      if (is.null(res)) return()
      rv$reviewed <- res
      rv$candidate <- NULL
      set_message(paste("Reviewed revision", sg_mask_revision(res)))
    })

    shiny::observeEvent(input$discard, {
      rv$candidate <- NULL
      set_message("Candidate discarded; reviewed data unchanged.")
    })

    output$review_status <- shiny::renderText({
      rev <- if (is.null(rv$reviewed)) "none" else
        substr(sg_mask_revision(rv$reviewed), 1, 19)
      cand <- if (is.null(rv$candidate)) "none" else
        paste(.sg_review(rv$candidate)$status,
              substr(sg_mask_revision(rv$candidate), 1, 19))
      paste0("Reviewed: ", rev, " | Candidate: ", cand)
    })

    output$overlay <- shiny::renderPlot({
      shiny::req(rv$image)
      mask <- rv$candidate %||% rv$reviewed
      ch <- as.integer(input$channel %||% 1L)
      print(sg_plot_overlay(rv$image, mask, channel = ch))
    })

    output$message <- shiny::renderText(rv$message)

    output$measurements <- shiny::renderTable({
      shiny::req(rv$run, rv$run$measurements)
      utils::head(as.data.frame(rv$run$measurements), 10L)
    })

    output$export <- shiny::downloadHandler(
      filename = function() "segmantR-bundle.zip",
      content = function(file) {
        mask <- rv$reviewed %||% rv$candidate
        if (is.null(mask)) {
          stop("Nothing to export.")
        }
        dir <- tempfile("sg_app_export_")
        on.exit(unlink(dir, recursive = TRUE), add = TRUE)
        sg_export_interchange(list(image = rv$image, mask = mask,
                                   run = if (is.null(rv$reviewed)) rv$run),
                              dir, image = NULL)
        .sg_zip_dir(dir, file)
      }
    )
  }
  shiny::shinyApp(ui, server)
}

#' Normalise app input
#' @noRd
.sg_app_initial <- function(input) {
  out <- list(image = NULL, candidate = NULL, reviewed = NULL, message = NULL)
  if (is.null(input)) return(out)
  if (is.character(input) && length(input) == 1L) {
    rep <- sg_import_interchange(input)
    out$image <- rep$image
    out$candidate <- rep$mask
    out$message <- "Imported bundle; the mask is staged for review."
    return(out)
  }
  if (inherits(input, "sg_image")) {
    out$image <- input
    return(out)
  }
  if (inherits(input, "sg_mask")) input <- list(mask = input)
  if (is.list(input)) {
    if (!is.null(input$image)) .sg_assert_image(input$image)
    out$image <- input$image
    if (!is.null(input$mask)) {
      .sg_assert_mask(input$mask)
      if (.sg_review(input$mask)$status == "reviewed") {
        out$reviewed <- input$mask
      } else {
        out$candidate <- input$mask
      }
    }
    return(out)
  }
  .sg_abort("Unsupported app input.", code = "VALIDATION_FAILED")
}

#' Shiny input widget for one protocol parameter
#' @noRd
.sg_param_widget <- function(row, override = NULL) {
  id <- paste0("param_", row$name)
  label <- paste0(row$name, if (!is.na(row$unit) && row$unit != "none")
    paste0(" [", row$unit, "]") else "")
  default <- override %||% row$default[[1]]
  enum <- row$enum[[1]]
  if (length(enum)) {
    return(shiny::selectInput(id, label, choices = as.character(enum),
                              selected = as.character(default)))
  }
  switch(
    row$type,
    boolean = shiny::checkboxInput(id, label, value = isTRUE(default)),
    string = shiny::textInput(id, label, value = default %||% ""),
    shiny::numericInput(
      id, label, value = if (is.null(default)) NA else default,
      min = if (is.na(row$minimum)) NA else row$minimum,
      max = if (is.na(row$maximum)) NA else row$maximum,
      step = if (row$type == "integer") 1 else NA
    )
  )
}

#' Control service capabilities (segmantR-control-v1)
#'
#' The local control service lets a partner (qupflowR, annotatR) drive a
#' running segmantR app through typed commands. It is **planned** and not
#' implemented; this function reports the planned contract so partners can
#' check for it without guessing. It never starts a server.
#'
#' @return A list with `schema`, `status` (`"planned"`), `implemented`
#'   (`FALSE`), `default` (`"off"`), `planned_commands` and
#'   `security_requirements`.
#' @export
#' @examples
#' sg_control_capabilities()$status
sg_control_capabilities <- function() {
  list(
    schema = "segmantR-control-v1",
    schema_version = "0.0.0",
    status = "planned",
    implemented = FALSE,
    default = "off",
    reason = paste("Contract drafted in INTEROP.md; no server, contract or",
                   "browser tests exist yet, so it is not offered."),
    planned_functions = c("sg_control_start", "sg_control_stop",
                          "sg_control_capabilities", "sg_control_state",
                          "sg_control_events", "sg_control_command"),
    planned_commands = c("session.load", "view.set_plane", "protocol.validate",
                         "protocol.run", "mask.preview", "mask.stage",
                         "mask.review", "bundle.export", "service.close"),
    security_requirements = c(
      "loopback only (127.0.0.1)", "random short-lived bearer token with TTL",
      "request size and path limits", "request_id on every request",
      "expected_revision on every mutation", "idempotency keys",
      "no eval, DOM or free code endpoints",
      "stops only its own service"
    )
  )
}
