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

info_label <- function(input_id, label, description, href) {
  div(
    class = "control-label-row",
    tags$label(
      id = paste0(input_id, "-label"),
      `for` = input_id,
      label
    ),
    div(
      class = "control-info",
      tags$button(
        class = "control-info-button",
        type = "button",
        title = paste("About", label),
        `aria-label` = paste("About", label),
        "i"
      ),
      div(
        class = "control-info-popover",
        tags$span(description),
        tags$a(
          class = "control-info-link",
          href = href,
          target = "_blank",
          rel = "noopener noreferrer",
          title = paste("Open", label, "documentation in a new tab"),
          `aria-label` = paste("Open", label, "documentation in a new tab"),
          tags$span(class = "external-arrow", `aria-hidden` = "true")
        )
      )
    )
  )
}

# This mirrors the addr pkgdown and hex-sticker palette without adding a UI package.
addr_css <- "
:root {
  --addr-body: #4D7183;
  --addr-fg: #396175;
  --addr-primary: #C28273;
  --addr-info: #EACEC5;
  --addr-warning: #E49865;
  --addr-blue: #8CB4C3;
  --addr-border: #CBD6D5;
  --addr-cream: #F6EDDE;
}

html,
body {
  background-color: #FFFFFF;
}

body {
  color: var(--addr-body);
}

.container-fluid {
  max-width: 960px;
  padding-bottom: 3rem;
  padding-top: 2rem;
}

.app-title {
  align-items: center;
  border-bottom: 3px solid var(--addr-info);
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  justify-content: space-between;
  margin-bottom: 1.5rem;
  padding-bottom: 0.6rem;
}

.app-title h2 {
  margin: 0;
}

.release-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.release-badge {
  border-radius: 0.2rem;
  display: inline-flex;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.5;
  overflow: hidden;
  text-decoration: none;
}

.release-badge:hover,
.release-badge:focus {
  text-decoration: none;
}

.release-badge-name,
.release-badge-value {
  color: #FFFFFF;
  padding: 0.1rem 0.4rem;
}

.release-badge-name {
  background: var(--addr-fg);
}

.release-badge-value {
  background: var(--addr-primary);
}

.release-badge-taf .release-badge-value {
  background: var(--addr-blue);
}

h4,
label,
#status {
  color: var(--addr-fg);
}

a {
  color: var(--addr-primary);
}

a:hover,
a:focus {
  color: var(--addr-warning);
}

code {
  background-color: rgba(57, 97, 117, 0.04);
  border-radius: 0.2rem;
  color: var(--addr-fg);
  padding: 0.125rem 0.25rem;
}

.input-options {
  align-items: flex-start;
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.control-field-upload {
  width: 300px;
}

.control-field-preset {
  width: 190px;
}

.control-field-workers {
  width: 90px;
}

.control-field .shiny-input-container {
  margin-bottom: 0;
  width: 100% !important;
}

.progress.shiny-file-input-progress {
  height: 0;
  margin-bottom: 0;
  overflow: hidden;
}

.progress.shiny-file-input-progress[style*='visibility: visible'] {
  height: 20px;
}

.control-label-row {
  align-items: center;
  display: flex;
  gap: 0.35rem;
  margin-bottom: 5px;
}

.control-label-row > label {
  margin: 0;
}

.control-info {
  display: inline-block;
  position: relative;
}

.control-info-button {
  align-items: center;
  background: transparent;
  border: 1px solid var(--addr-blue);
  border-radius: 50%;
  color: var(--addr-fg);
  cursor: pointer;
  display: inline-flex;
  font-size: 10px;
  font-weight: 700;
  height: 16px;
  justify-content: center;
  line-height: 1;
  padding: 0;
  width: 16px;
}

.control-info:hover > .control-info-button,
.control-info:focus-within > .control-info-button {
  background: rgba(140, 180, 195, 0.18);
}

.control-info-popover {
  background: #FFFFFF;
  border: 1px solid var(--addr-border);
  border-radius: 0.2rem;
  box-shadow: 0 0.25rem 0.75rem rgba(57, 97, 117, 0.16);
  color: var(--addr-body);
  display: none;
  font-size: 12px;
  font-weight: 400;
  left: 0;
  line-height: 1.4;
  padding: 0.6rem 0.7rem;
  position: absolute;
  top: calc(100% + 0.25rem);
  width: 230px;
  z-index: 10;
}

.control-info-popover::before {
  content: '';
  height: 0.3rem;
  left: 0;
  position: absolute;
  right: 0;
  top: -0.3rem;
}

.control-info:hover .control-info-popover,
.control-info:focus-within .control-info-popover {
  display: block;
}

.control-info-link {
  display: inline-flex;
  height: 13px;
  margin-left: 0.35rem;
  position: relative;
  text-decoration: none;
  vertical-align: -2px;
  width: 13px;
}

.external-arrow {
  color: currentColor;
  display: inline-block;
  height: 12px;
  position: relative;
  width: 12px;
}

.external-arrow::before {
  background: currentColor;
  bottom: 2px;
  content: '';
  height: 2px;
  left: 1px;
  position: absolute;
  transform: rotate(-45deg);
  width: 7px;
}

.external-arrow::after {
  border-right: 2px solid currentColor;
  border-top: 2px solid currentColor;
  content: '';
  height: 5px;
  position: absolute;
  right: 1px;
  top: 1px;
  width: 5px;
}

.action-row {
  align-items: center;
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 1rem;
}

.privacy-note {
  background: rgba(140, 180, 195, 0.1);
  border-left: 3px solid var(--addr-blue);
  color: #6B8490;
  font-size: 0.85em;
  margin: 0.75rem 0;
  padding: 0.5rem 0.75rem;
}

.app-footer {
  border-top: 1px solid var(--addr-border);
  color: #6B8490;
  font-size: 0.85em;
  margin-top: 1.25rem;
  padding-top: 0.75rem;
}

.download-result {
  white-space: nowrap;
}

.form-control {
  border-color: var(--addr-border);
  border-radius: 0.2rem;
}

.form-control:focus {
  border-color: var(--addr-blue);
  box-shadow: 0 0 0 1px var(--addr-blue);
}

.btn-primary,
.btn-primary:focus {
  background: var(--addr-primary);
  border-color: var(--addr-primary);
}

.btn-primary:hover,
.btn-primary:active,
.btn-primary:active:hover {
  background: var(--addr-warning);
  border-color: var(--addr-warning);
}

.btn-primary[disabled],
.btn-primary[disabled]:hover,
.btn-primary[disabled]:focus {
  background: #E3E7E8;
  border-color: var(--addr-border);
  color: #7A8D96;
  cursor: not-allowed;
  opacity: 1;
}

hr {
  border-top-color: var(--addr-border);
}

#status {
  font-weight: 600;
  margin-bottom: 0.75rem;
}

#status:empty {
  display: none;
}

#progress {
  background: var(--addr-cream);
  border: 1px solid var(--addr-border);
  border-left: 4px solid var(--addr-blue);
  border-radius: 0.2rem;
  color: var(--addr-fg);
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.85em;
  height: 18rem;
  line-height: 1.45;
  overflow-wrap: anywhere;
  overflow-y: auto;
  padding: 0.9rem;
  white-space: pre-wrap;
}
"

progress_javascript <- "
$(document).on('shiny:connected', function() {
  var progress = document.getElementById('progress');
  if (!progress || progress.dataset.addrFollow === 'true') {
    return;
  }

  var followBottom = function() {
    progress.scrollTop = progress.scrollHeight;
  };

  new MutationObserver(followBottom).observe(progress, {
    childList: true,
    characterData: true,
    subtree: true
  });
  progress.dataset.addrFollow = 'true';
  followBottom();
});

Shiny.addCustomMessageHandler('addrJobState', function(running) {
  var upload = document.getElementById('upload');
  var preset = document.getElementById('preset');
  var workers = document.getElementById('workers');

  if (upload) {
    upload.disabled = running;
  }
  if (preset) {
    if (preset.selectize) {
      if (running) {
        preset.selectize.disable();
      } else {
        preset.selectize.enable();
      }
    } else {
      preset.disabled = running;
    }
  }
  if (workers) {
    workers.disabled = running;
  }
});
"

app_state <- new.env(parent = emptyenv())
app_state$busy <- FALSE

ui <- fluidPage(
  tags$head(
    tags$title("addr geocoder"),
    tags$style(HTML(addr_css)),
    tags$script(HTML(progress_javascript))
  ),
  div(
    class = "app-title",
    h2("addr geocoder"),
    div(
      class = "release-badges",
      tags$a(
        class = "release-badge",
        href = "https://github.com/geomarker-io/addr/releases/tag/v2.0.0",
        target = "_blank",
        rel = "noopener noreferrer",
        title = "addr 2.0.0 release",
        tags$span(class = "release-badge-name", "addr"),
        tags$span(class = "release-badge-value", "v2.0.0")
      ),
      tags$a(
        class = "release-badge release-badge-taf",
        href = "https://www.census.gov/geographies/mapping-files/2025/geo/tiger-line-file.html",
        target = "_blank",
        rel = "noopener noreferrer",
        title = "2025 Census TIGER address-file bundle",
        tags$span(class = "release-badge-name", "TIGER"),
        tags$span(class = "release-badge-value", "2025")
      )
    )
  ),
  p(
    HTML(paste0(
      "Geocoding matches addresses to Census TIGER street data and estimates ",
      "their locations. Geocoded results include the match stage, matched ZIP ",
      "code and street, longitude, latitude, and an S2 cell, and are downloaded ",
      "as a copy of the input file with new columns added. Learn more in the ",
      '<a href="https://geomarker.io/addr/reference/geocode.html" ',
      'target="_blank" rel="noopener noreferrer">',
      "addr geocoding documentation</a> and on the homepage at ",
      '<a href="https://geomarker.io/addr" target="_blank" ',
      'rel="noopener noreferrer">https://geomarker.io/addr</a>.'
    ))
  ),
  div(
    class = "input-options",
    div(
      class = "control-field control-field-upload",
      info_label(
        "upload",
        "Upload",
        "Choose one CSV or Parquet file with a column named exactly address.",
        "https://github.com/geomarker-io/addr/tree/v2.0.0#batch-geocoding-on-a-cluster"
      ),
      fileInput(
        "upload",
        label = NULL,
        multiple = FALSE,
        accept = c(".csv", ".parquet", "text/csv", "application/octet-stream")
      )
    ),
    div(
      class = "control-field control-field-preset",
      info_label(
        "preset",
        "Geocoding preset",
        "Choose how strictly ZIP codes and street names must match.",
        "https://github.com/geomarker-io/addr/tree/v2.0.0#batch-geocoding-on-a-cluster"
      ),
      selectInput(
        "preset",
        label = NULL,
        choices = c("default", "strict", "exact-zip", "loose"),
        selected = "default"
      )
    ),
    div(
      class = "control-field control-field-workers",
      info_label(
        "workers",
        "Workers",
        "Run ZIP groups in parallel; more workers use more memory.",
        "https://geomarker.io/addr/reference/geocode.html#details"
      ),
      numericInput(
        "workers",
        label = NULL,
        value = default_workers,
        min = 1,
        step = 1
      )
    )
  ),
  p(
    class = "privacy-note",
    "Uploaded data is processed only on the machine running this container",
    "using temporary session storage, and is never sent over the internet to",
    "a third party."
  ),
  tags$hr(),
  div(
    class = "action-row",
    uiOutput("run_ui", inline = TRUE),
    uiOutput("download_ui", inline = TRUE)
  ),
  textOutput("status"),
  verbatimTextOutput("progress", placeholder = TRUE),
  tags$footer(
    class = "app-footer",
    HTML(paste0(
      "Please submit issues or contribute changes in the ",
      '<a href="https://github.com/geomarker-io/addr_geocoder" ',
      'target="_blank" rel="noopener noreferrer">',
      "addr_geocoder GitHub repository</a>."
    ))
  )
)

server <- function(input, output, session) {
  state <- reactiveValues(
    running = FALSE,
    status = "",
    log = character(),
    truncated = FALSE,
    output_path = NULL
  )

  runtime <- new.env(parent = emptyenv())
  runtime$process <- NULL
  runtime$owns_lock <- FALSE
  runtime$job_dir <- NULL
  runtime$output_dir <- NULL
  runtime$screen <- ""
  runtime$cursor_row <- 1L
  runtime$cursor_column <- 1L
  runtime$ansi <- ""

  ensure_terminal_row <- function(row = runtime$cursor_row) {
    missing_rows <- row - length(runtime$screen)
    if (missing_rows > 0L) {
      runtime$screen <- c(runtime$screen, rep("", missing_rows))
    }
    invisible(NULL)
  }

  truncate_terminal <- function() {
    extra_rows <- length(runtime$screen) - 2000L
    if (extra_rows > 0L) {
      runtime$screen <- tail(runtime$screen, 2000L)
      runtime$cursor_row <- max(1L, runtime$cursor_row - extra_rows)
      state$truncated <- TRUE
    }
    invisible(NULL)
  }

  publish_terminal <- function() {
    lines <- runtime$screen
    while (length(lines) > 0L && !nzchar(tail(lines, 1L))) {
      lines <- head(lines, -1L)
    }
    state$log <- lines
    invisible(NULL)
  }

  reset_terminal <- function() {
    runtime$screen <- ""
    runtime$cursor_row <- 1L
    runtime$cursor_column <- 1L
    runtime$ansi <- ""
    state$log <- character()
    state$truncated <- FALSE
    invisible(NULL)
  }

  write_terminal_character <- function(character) {
    ensure_terminal_row()
    line <- runtime$screen[[runtime$cursor_row]]
    line_length <- nchar(line, type = "chars")

    if (runtime$cursor_column > line_length + 1L) {
      line <- paste0(
        line,
        strrep(" ", runtime$cursor_column - line_length - 1L)
      )
      line_length <- nchar(line, type = "chars")
    }

    prefix <- if (runtime$cursor_column > 1L) {
      substr(line, 1L, runtime$cursor_column - 1L)
    } else {
      ""
    }
    suffix <- if (runtime$cursor_column <= line_length) {
      substr(line, runtime$cursor_column + 1L, line_length)
    } else {
      ""
    }

    runtime$screen[[runtime$cursor_row]] <- paste0(prefix, character, suffix)
    runtime$cursor_column <- runtime$cursor_column + 1L
    invisible(NULL)
  }

  handle_ansi <- function(sequence) {
    if (!startsWith(sequence, "\033[") || nchar(sequence) < 3L) {
      return(invisible(NULL))
    }

    final <- substr(sequence, nchar(sequence), nchar(sequence))
    parameter_text <- substr(sequence, 3L, nchar(sequence) - 1L)
    first_parameter <- if (nzchar(parameter_text)) {
      strsplit(parameter_text, ";", fixed = TRUE)[[1L]][[1L]]
    } else {
      NA_character_
    }
    first_parameter <- suppressWarnings(as.integer(first_parameter))
    amount <- if (is.na(first_parameter) || first_parameter == 0L) {
      1L
    } else {
      first_parameter
    }

    if (identical(final, "A")) {
      runtime$cursor_row <- max(1L, runtime$cursor_row - amount)
    } else if (identical(final, "B")) {
      runtime$cursor_row <- runtime$cursor_row + amount
      ensure_terminal_row()
    } else if (identical(final, "C")) {
      runtime$cursor_column <- runtime$cursor_column + amount
    } else if (identical(final, "D")) {
      runtime$cursor_column <- max(1L, runtime$cursor_column - amount)
    } else if (identical(final, "G")) {
      runtime$cursor_column <- amount
    } else if (identical(final, "K")) {
      ensure_terminal_row()
      mode <- if (is.na(first_parameter)) 0L else first_parameter
      line <- runtime$screen[[runtime$cursor_row]]
      line_length <- nchar(line, type = "chars")

      if (mode == 2L) {
        runtime$screen[[runtime$cursor_row]] <- ""
      } else if (mode == 1L) {
        suffix <- if (runtime$cursor_column < line_length) {
          substr(line, runtime$cursor_column + 1L, line_length)
        } else {
          ""
        }
        runtime$screen[[runtime$cursor_row]] <- paste0(
          strrep(" ", min(runtime$cursor_column, line_length)),
          suffix
        )
      } else {
        runtime$screen[[runtime$cursor_row]] <- if (runtime$cursor_column > 1L) {
          substr(line, 1L, runtime$cursor_column - 1L)
        } else {
          ""
        }
      }
    }
    invisible(NULL)
  }

  append_chunk <- function(chunk, flush = FALSE) {
    if (!length(chunk) || is.na(chunk) || !nzchar(chunk)) {
      if (flush) {
        runtime$ansi <- ""
        publish_terminal()
      }
      return(invisible(NULL))
    }

    characters <- strsplit(chunk, "", fixed = TRUE)[[1L]]

    for (character in characters) {
      if (nzchar(runtime$ansi)) {
        runtime$ansi <- paste0(runtime$ansi, character)
        if (startsWith(runtime$ansi, "\033[")) {
          final_byte <- utf8ToInt(character)
          if (
            nchar(runtime$ansi) > 2L &&
              final_byte >= 64L &&
              final_byte <= 126L
          ) {
            handle_ansi(runtime$ansi)
            runtime$ansi <- ""
          }
        } else if (startsWith(runtime$ansi, "\033]")) {
          if (
            identical(character, "\a") ||
              endsWith(runtime$ansi, paste0("\033", "\\"))
          ) {
            runtime$ansi <- ""
          }
        } else if (nchar(runtime$ansi) >= 2L) {
          runtime$ansi <- ""
        }
      } else if (identical(character, "\033")) {
        runtime$ansi <- character
      } else if (identical(character, "\r")) {
        runtime$cursor_column <- 1L
      } else if (identical(character, "\n")) {
        runtime$cursor_row <- runtime$cursor_row + 1L
        runtime$cursor_column <- 1L
        ensure_terminal_row()
        truncate_terminal()
      } else if (identical(character, "\b")) {
        runtime$cursor_column <- max(1L, runtime$cursor_column - 1L)
      } else {
        write_terminal_character(character)
      }
    }

    if (flush) {
      runtime$ansi <- ""
    }
    publish_terminal()
    invisible(NULL)
  }

  append_lines <- function(lines) {
    if (length(lines) > 0L) {
      append_chunk(paste0(paste(lines, collapse = "\n"), "\n"))
    }
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
    session$sendCustomMessage("addrJobState", FALSE)
    release_lock()

    if (identical(exit_status, 0L) && length(output_files) == 1L) {
      state$output_path <- output_files[[1L]]
      state$status <- "Geocoding complete."
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

  output$run_ui <- renderUI({
    button <- actionButton(
      "run",
      "Geocode",
      class = "btn-primary"
    )
    if (isTRUE(state$running) || is.null(input$upload)) {
      button <- htmltools::tagAppendAttributes(button, disabled = "disabled")
    }
    button
  })

  observeEvent(input$upload, {
    if (isTRUE(state$running)) {
      return()
    }
    remove_previous_job()
    reset_terminal()
    state$status <- ""
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
    reset_terminal()
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
    session$sendCustomMessage("addrJobState", TRUE)
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
    paste(lines, collapse = "\n")
  })

  output$download_ui <- renderUI({
    path <- state$output_path
    if (is.null(path) || !file.exists(path)) {
      return(NULL)
    }
    tags$span(
      class = "download-result",
      "Results: ",
      downloadLink("download", basename(path))
    )
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
