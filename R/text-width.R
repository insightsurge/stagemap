# The cache belongs only to this package and is populated on first use.
the <- new.env(parent = emptyenv())

#' Locate R's installed Helvetica metrics without bundling a copy
#' @noRd
helvetica_metrics_file <- function() {
  system.file("afm", "Helvetica.afm.gz", package = "grDevices")
}

#' Read printable ASCII widths, with a usable fallback if the file is unreadable
#' @noRd
helvetica_metrics <- function() {
  if (!is.null(the$helvetica)) {
    return(the$helvetica)
  }
  file <- helvetica_metrics_file()
  lines <- suppressWarnings(tryCatch(
    {
      connection <- gzfile(file, open = "rt")
      on.exit(close(connection))
      readLines(connection, warn = FALSE)
    },
    error = function(error) character()
  ))
  pattern <- "^C[[:space:]]+(-?[0-9]+)[[:space:]]*;[[:space:]]*WX[[:space:]]+([0-9.]+)[[:space:]]*;.*$"
  lines <- lines[grepl(pattern, lines)]
  codes <- as.integer(sub(pattern, "\\1", lines))
  widths <- as.numeric(sub(pattern, "\\2", lines))
  keep <- codes >= 32L & codes <= 126L & is.finite(widths)
  result <- list(widths = rep(556, 95L), other = if (any(keep)) 600 else 556)
  names(result$widths) <- as.character(32:126)
  result$widths[as.character(codes[keep])] <- widths[keep]
  the$helvetica <- result
  result
}

#' Estimate text widths in pixels without opening a graphics device
#' @noRd
text_width <- function(text, size) {
  checkmate::assert_character(text, any.missing = FALSE)
  checkmate::assert_number(size, lower = 0, finite = TRUE)
  # Label widths use Helvetica metrics; a page using another font can differ.
  metrics <- helvetica_metrics()
  vapply(
    strsplit(enc2utf8(text), "", fixed = TRUE),
    function(chars) {
      codes <- vapply(chars, utf8ToInt, integer(1))
      widths <- unname(metrics$widths[as.character(codes)])
      widths[is.na(widths)] <- metrics$other
      sum(widths) * size / 1000
    },
    numeric(1),
    USE.NAMES = FALSE
  )
}

#' Wrap one label on spaces, splitting words that cannot fit on a line
#' @noRd
wrap_label <- function(text, width, size) {
  checkmate::assert_string(text)
  checkmate::assert_number(width, lower = 0, finite = TRUE)
  checkmate::assert_number(size, lower = 0, finite = TRUE)
  text <- gsub("\r\n", "\n", enc2utf8(text), fixed = TRUE)
  if (grepl("\n", text, fixed = TRUE)) {
    # Appending a separator preserves the final empty part that strsplit() otherwise drops.
    parts <- strsplit(paste0(text, "\n"), "\n", fixed = TRUE)[[1L]]
    return(unlist(lapply(parts, wrap_label, width = width, size = size), use.names = FALSE))
  }
  words <- strsplit(text, " ", fixed = TRUE)[[1L]]
  words <- words[nzchar(words)]
  if (!length(words)) {
    return("")
  }
  lines <- character()
  line <- ""
  for (word in words) {
    candidate <- if (nzchar(line)) paste(line, word) else word
    if (text_width(candidate, size) * 1.05 <= width) {
      line <- candidate
      next
    }
    if (nzchar(line)) {
      lines <- c(lines, line)
    }
    line <- ""
    for (char in strsplit(word, "", fixed = TRUE)[[1L]]) {
      candidate <- paste0(line, char)
      if (nzchar(line) && text_width(candidate, size) * 1.05 > width) {
        lines <- c(lines, line)
        line <- ""
      }
      line <- paste0(line, char)
    }
  }
  c(lines, line)
}
