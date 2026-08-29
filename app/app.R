shiny_port_value <- Sys.getenv("SHINY_PORT", unset = "3838")
Sys.unsetenv("SHINY_PORT")

suppressPackageStartupMessages({
  library(shiny)
})

options(shiny.maxRequestSize = Inf)

parse_positive_integer <- function(value, name, maximum = .Machine$integer.max) {
  if (
    length(value) != 1L ||
      is.na(value) ||
      !grepl("^[1-9][0-9]*$", as.character(value))
  ) {
    stop(name, " must be a positive integer", call. = FALSE)
  }

  parsed <- suppressWarnings(as.numeric(value))
  if (!is.finite(parsed) || parsed > maximum || parsed != floor(parsed)) {
    stop(name, " must be a positive integer", call. = FALSE)
  }
  as.integer(parsed)
}

default_workers <- parse_positive_integer(
  Sys.getenv("ADDR_GEOCODE_WORKERS", unset = "2"),
  "ADDR_GEOCODE_WORKERS"
)
shiny_port <- parse_positive_integer(
  shiny_port_value,
  "SHINY_PORT",
  maximum = 65535L
)

safe_upload_name <- function(name) {
  name <- basename(name)
  extension <- tolower(tools::file_ext(name))
  if (!extension %in% c("csv", "parquet")) {
    stop("input must be a .csv or .parquet file", call. = FALSE)
  }

  stem <- tools::file_path_sans_ext(name)
  stem <- gsub("[^A-Za-z0-9._-]+", "-", stem)
  stem <- gsub("(^[-.]+|[-.]+$)", "", stem)
  if (!nzchar(stem)) {
    stem <- "addresses"
  }
  paste0(stem, ".", extension)
}

strip_ansi <- function(x) {
  gsub("\033\\[[0-?]*[ -/]*[@-~]", "", x, perl = TRUE)
}

app_state <- new.env(parent = emptyenv())
app_state$busy <- FALSE

ui <- fluidPage(
  titlePanel("addr geocoder"),
  p(
    "Upload one CSV or Parquet file containing a column named exactly",
    code("address"),
    "."
  ),
  uiOutput("controls"),
  tags$hr(),
  h4("Status"),
  textOutput("status"),
  verbatimTextOutput("progress", placeholder = TRUE),
  uiOutput("download_ui")
)

server <- function(input, output, session) {
  state <- reactiveValues(
    running = FALSE,
    status = "Choose a file to begin.",
    log = character(),
    partial = "",
    truncated = FALSE,
    output_path = NULL
  )

  runtime <- new.env(parent = emptyenv())
  runtime$process <- NULL
  runtime$owns_lock <- FALSE
  runtime$job_dir <- NULL
  runtime$output_dir <- NULL
  runtime$pending <- ""

  append_lines <- function(lines) {
    if (length(lines) == 0L) {
      return(invisible(NULL))
    }
    lines <- lines[nzchar(trimws(lines))]
    if (length(lines) == 0L) {
      return(invisible(NULL))
    }

    combined <- c(state$log, lines)
    if (length(combined) > 2000L) {
      state$truncated <- TRUE
      combined <- tail(combined, 2000L)
    }
    state$log <- combined
    invisible(NULL)
  }

  append_chunk <- function(chunk, flush = FALSE) {
    if (!length(chunk) || is.na(chunk) || !nzchar(chunk)) {
      if (flush && nzchar(runtime$pending)) {
        append_lines(runtime$pending)
        runtime$pending <- ""
        state$partial <- ""
      }
      return(invisible(NULL))
    }

    chunk <- strip_ansi(chunk)
    chunk <- gsub("\r", "\n", chunk, fixed = TRUE)
    value <- paste0(runtime$pending, chunk)
    pieces <- strsplit(value, "\n", fixed = TRUE)[[1L]]
    complete <- head(pieces, -1L)
    runtime$pending <- tail(pieces, 1L)

    append_lines(complete)
    if (flush && nzchar(runtime$pending)) {
      append_lines(runtime$pending)
      runtime$pending <- ""
    }
    state$partial <- runtime$pending
    invisible(NULL)
  }

  drain_process_output <- function(flush = FALSE) {
    process <- runtime$process
    if (is.null(process)) {
      return(invisible(NULL))
    }

    repeat {
      poll <- tryCatch(process$poll_io(0), error = function(err) NULL)
      if (is.null(poll) || !poll[["output"]] %in% c("ready", "closed")) {
        break
      }

      chunk <- tryCatch(process$read_output(), error = function(err) "")
      append_chunk(chunk)
      if (!identical(poll[["output"]], "ready") || !nzchar(chunk)) {
        break
      }
    }

    if (flush) {
      append_chunk("", flush = TRUE)
    }
    invisible(NULL)
  }

  release_lock <- function() {
    if (isTRUE(runtime$owns_lock)) {
      app_state$busy <- FALSE
      runtime$owns_lock <- FALSE
    }
    invisible(NULL)
  }

  remove_previous_job <- function() {
    if (!is.null(runtime$job_dir) && dir.exists(runtime$job_dir)) {
      unlink(runtime$job_dir, recursive = TRUE, force = TRUE)
    }
    runtime$job_dir <- NULL
    runtime$output_dir <- NULL
    state$output_path <- NULL
    invisible(NULL)
  }

  finish_job <- function() {
    process <- runtime$process
    if (is.null(process)) {
      return(invisible(NULL))
    }

    drain_process_output(flush = TRUE)
    exit_status <- tryCatch(process$get_exit_status(), error = function(err) NA_integer_)
    output_files <- if (!is.null(runtime$output_dir) && dir.exists(runtime$output_dir)) {
      list.files(
        runtime$output_dir,
        pattern = "[.](csv|parquet)$",
        full.names = TRUE,
        ignore.case = TRUE
      )
    } else {
      character()
    }

    runtime$process <- NULL
    state$running <- FALSE
    release_lock()

    if (identical(exit_status, 0L) && length(output_files) == 1L) {
      state$output_path <- output_files[[1L]]
      state$status <- "Geocoding complete. Download the file below."
    } else if (identical(exit_status, 0L)) {
      state$status <- paste0(
        "Geocoding finished, but expected one output file and found ",
        length(output_files),
        "."
      )
    } else {
      state$status <- paste0("Geocoding failed with exit status ", exit_status, ".")
    }
    invisible(NULL)
  }

  output$controls <- renderUI({
    if (isTRUE(state$running)) {
      return(p("Geocoding is running. Upload and Run controls are temporarily hidden."))
    }

    tagList(
      fileInput(
        "upload",
        "Address file",
        multiple = FALSE,
        accept = c(".csv", ".parquet", "text/csv", "application/octet-stream")
      ),
      selectInput(
        "preset",
        "Geocoding preset",
        choices = c("default", "strict", "exact-zip", "loose"),
        selected = "default"
      ),
      numericInput(
        "workers",
        "Workers",
        value = default_workers,
        min = 1,
        step = 1
      ),
      actionButton("run", "Run geocoding")
    )
  })

  observeEvent(input$upload, {
    if (isTRUE(state$running)) {
      return()
    }
    remove_previous_job()
    state$log <- character()
    state$partial <- ""
    state$truncated <- FALSE
    state$status <- paste0("Ready to geocode ", basename(input$upload$name), ".")
  }, ignoreInit = TRUE)

  observeEvent(input$run, {
    upload <- isolate(input$upload)
    if (is.null(upload) || nrow(upload) != 1L) {
      showNotification("Choose one CSV or Parquet file first.", type = "error")
      return()
    }
    if (isTRUE(app_state$busy)) {
      state$status <- "Another geocoding job is already running in this app."
      return()
    }

    workers <- tryCatch(
      parse_positive_integer(isolate(input$workers), "Workers"),
      error = identity
    )
    if (inherits(workers, "error")) {
      state$status <- conditionMessage(workers)
      return()
    }

    preset <- isolate(input$preset)
    if (length(preset) != 1L || !preset %in% c("default", "strict", "exact-zip", "loose")) {
      state$status <- "Geocoding preset is invalid."
      return()
    }

    input_name <- tryCatch(safe_upload_name(upload$name), error = identity)
    if (inherits(input_name, "error")) {
      state$status <- conditionMessage(input_name)
      return()
    }

    remove_previous_job()
    runtime$job_dir <- tempfile("addr-geocoder-")
    input_dir <- file.path(runtime$job_dir, "input")
    runtime$output_dir <- file.path(runtime$job_dir, "output")
    dir.create(input_dir, recursive = TRUE, mode = "0700")
    dir.create(runtime$output_dir, recursive = TRUE, mode = "0700")
    input_path <- file.path(input_dir, input_name)

    copied <- file.copy(upload$datapath, input_path, overwrite = FALSE)
    if (!isTRUE(copied)) {
      remove_previous_job()
      state$status <- "Could not stage the uploaded file."
      return()
    }

    app_state$busy <- TRUE
    runtime$owns_lock <- TRUE
    runtime$pending <- ""
    state$log <- character()
    state$partial <- ""
    state$truncated <- FALSE
    state$status <- paste0(
      "Running addr-geocode with preset ",
      preset,
      " and ",
      workers,
      if (workers == 1L) " worker." else " workers."
    )

    process <- tryCatch(
      processx::process$new(
        "/usr/local/bin/addr-geocode",
        args = c(
          "--input", input_path,
          "--output-dir", runtime$output_dir,
          "--workers", as.character(workers),
          "--preset", preset
        ),
        stdout = "|",
        stderr = "2>&1",
        cleanup_tree = TRUE
      ),
      error = identity
    )
    if (inherits(process, "error")) {
      append_lines(paste0("addr-geocode: ", conditionMessage(process)))
      state$status <- "Could not start addr-geocode."
      release_lock()
      return()
    }

    runtime$process <- process
    state$running <- TRUE
  }, ignoreInit = TRUE)

  observe({
    invalidateLater(250, session)
    if (!isTRUE(state$running) || is.null(runtime$process)) {
      return()
    }

    drain_process_output()
    alive <- tryCatch(runtime$process$is_alive(), error = function(err) FALSE)
    if (!isTRUE(alive)) {
      finish_job()
    }
  })

  output$status <- renderText(state$status)

  output$progress <- renderText({
    lines <- state$log
    if (isTRUE(state$truncated)) {
      lines <- c("[earlier progress omitted]", lines)
    }
    if (nzchar(state$partial)) {
      lines <- c(lines, state$partial)
    }
    paste(lines, collapse = "\n")
  })

  output$download_ui <- renderUI({
    path <- state$output_path
    if (is.null(path) || !file.exists(path)) {
      return(NULL)
    }
    tagList(h4("Output"), downloadLink("download", basename(path)))
  })

  output$download <- downloadHandler(
    filename = function() {
      basename(state$output_path)
    },
    content = function(file) {
      copied <- file.copy(state$output_path, file, overwrite = TRUE)
      if (!isTRUE(copied)) {
        stop("could not prepare the output download", call. = FALSE)
      }
    }
  )

  session$onSessionEnded(function() {
    process <- runtime$process
    if (!is.null(process)) {
      alive <- tryCatch(process$is_alive(), error = function(err) FALSE)
      if (isTRUE(alive)) {
        try(process$kill_tree(), silent = TRUE)
      }
    }
    release_lock()
    if (!is.null(runtime$job_dir) && dir.exists(runtime$job_dir)) {
      unlink(runtime$job_dir, recursive = TRUE, force = TRUE)
    }
  })
}

runApp(
  shinyApp(ui, server),
  host = "0.0.0.0",
  port = shiny_port,
  launch.browser = FALSE
)
