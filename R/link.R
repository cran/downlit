#' Automatically link inline code
#'
#' @param text String of code to highlight and link.
#' @return
#'   If `text` is linkable, an HTML link for `autolink()`, and or just
#'   the URL for `autolink_url()`. Both return `NA` if the text is not
#'   linkable.
#' @inheritSection highlight Options
#' @export
#' @examples
#' autolink("stats::median()")
#' autolink("vignette('grid', package = 'grid')")
#'
#' autolink_url("stats::median()")
autolink <- function(text) {
  href <- autolink_url(text)
  if (identical(href, NA_character_)) {
    return(NA_character_)
  }

  paste0("<a href='", href, "'>", escape_html(text), "</a>")
}

#' @export
#' @rdname autolink
autolink_url <- function(text) {
  expr <- safe_parse(text)
  if (length(expr) == 0) {
    return(NA_character_)
  }

  href_expr(expr[[1]])
}

autolink_curly <- function(text) {
  package_name <- extract_curly_package(text)
  if (is.na(package_name)) {
    return(NA_character_)
  }

  href <- href_package(package_name)
  if (is.na(href)) {
    return(NA_character_)
  }

  paste0("<a href='", href, "'>", package_name, "</a>")
}


# Helper for testing
href_expr_ <- function(expr, ...) {
  href_expr(substitute(expr), ...)
}

href_expr <- function(expr) {
  if (!is_call(expr)) {
    return(NA_character_)
  }

  fun <- expr[[1]]
  if (is_call(fun, "::", n = 2)) {
    pkg <- as.character(fun[[2]])
    fun <- fun[[3]]
  } else {
    pkg <- NULL
  }

  if (!is_symbol(fun))
    return(NA_character_)

  fun_name <- as.character(fun)
  n_args <- length(expr) - 1

  if (n_args == 0) {
    href_topic(fun_name, pkg, is_fun = TRUE)
  } else if (fun_name %in% c("library", "require", "requireNamespace")) {
    simple_call <- n_args == 1 &&
      is.null(names(expr)) &&
      (is_string(expr[[2]]) || (fun_name != "requireNamespace") && is_symbol(expr[[2]]))

    if (simple_call) {
      pkg <- as.character(expr[[2]])
      topic <- href_package(pkg)
      if (is.na(topic)) {
        href_topic(fun_name)
      } else {
        topic
      }
    } else {
      href_topic(fun_name, is_fun = TRUE)
    }
  } else if (fun_name == "vignette" && n_args >= 1) {
    # vignette("foo", "package")
    expr <- match.call(utils::vignette, expr)
    topic_ok <- is.character(expr$topic)
    package_ok <- is.character(expr$package) || is.null(expr$package)
    if (topic_ok && package_ok) {
      href_article(expr$topic, expr$package)
    } else {
      NA_character_
    }
  } else if (fun_name == "?" && n_args == 1) {
    topic <- expr[[2]]
    if (is_call(topic, "::")) {
      # ?pkg::x
      href_topic(as.character(topic[[3]]), as.character(topic[[2]]))
    } else if (is_symbol(topic) || is_string(topic)) {
      # ?x
      href_topic(as.character(expr[[2]]))
    } else {
      NA_character_
    }
  } else if (fun_name == "?" && n_args == 2) {
    # package?x
    href_topic(paste0(expr[[3]], "-", expr[[2]]))
  } else if (fun_name == "help" && n_args >= 1) {
    expr <- match.call(utils::help, expr)
    if (is_help_literal(expr$topic) && is_help_literal(expr$package)) {
      href_topic(as.character(expr$topic), as.character(expr$package))
    } else if (is_help_literal(expr$topic) && is.null(expr$package)) {
      href_topic(as.character(expr$topic))
    } else if (is.null(expr$topic) && is_help_literal(expr$package)) {
      href_package_ref(as.character(expr$package))
    } else {
      NA_character_
    }
  } else if (fun_name == "::" && n_args == 2) {
    href_topic(as.character(expr[[3]]), as.character(expr[[2]]))
  } else {
    NA_character_
  }
}

is_help_literal <- function(x) is_string(x) || is_symbol(x)

# Topics ------------------------------------------------------------------

#' Generate url for topic/article/package
#'
#' @param topic,article Topic/article name
#' @param package Optional package name. If not supplied, will search
#'   in all attached packages.
#' @param is_fun Only return topics that are (probably) for functions.
#' @keywords internal
#' @export
#' @return URL topic or article; `NA` if can't find one.
#' @examples
#' href_topic("t")
#' href_topic("DOESN'T EXIST")
#' href_topic("href_topic", "downlit")
#'
#' href_package("downlit")
href_topic <- function(topic, package = NULL, is_fun = FALSE) {
  if (length(topic) != 1L) {
    return(NA_character_)
  }
  if (is_package_local(package)) {
    href_topic_local(topic, is_fun = is_fun)
  } else {
    href_topic_remote(topic, package)
  }
}

is_package_local <- function(package) {
  if (is.null(package)) {
    return(TRUE)
  }
  cur <- getOption("downlit.package")
  if (is.null(cur)) {
    return(FALSE)
  }

  package == cur
}

href_topic_local <- function(topic, is_fun = FALSE) {
  rdname <- find_rdname(NULL, topic)
  if (is.null(rdname)) {
    # Check attached packages
    loc <- find_rdname_attached(topic, is_fun = is_fun)
    if (is.null(loc)) {
      return(NA_character_)
    } else {
      return(href_topic_remote(topic, loc$package))
    }
  }

  if (rdname == "reexports") {
    return(href_topic_reexported(topic, getOption("downlit.package")))
  }

  cur_rdname <- getOption("downlit.rdname", "")
  if (rdname == cur_rdname) {
    return(NA_character_)
  }

  if (cur_rdname != "") {
    paste0(rdname, ".html")
  } else {
    paste0(getOption("downlit.topic_path"), rdname, ".html")
  }
}

href_topic_remote <- function(topic, package) {
  rdname <- find_rdname(package, topic)
  if (is.null(rdname)) {
    return(NA_character_)
  }

  if (is_reexported(topic, package)) {
    href_topic_reexported(topic, package)
  } else {
    paste0(href_package_ref(package), "/", rdname, ".html")
  }
}

is_reexported <- function(name, package) {
  if (package == "base") {
    return(FALSE)
  }
  is_imported <- env_has(ns_imports_env(package), name)
  is_imported && is_exported(name, package)
}

is_exported <- function(name, package) {
  name %in% getNamespaceExports(ns_env(package))
}

# If it's a re-exported function, we need to work a little harder to
# find out its source so that we can link to it.
href_topic_reexported <- function(topic, package) {
  ns <- ns_env(package)
  if (!env_has(ns, topic, inherit = TRUE)) {
    return(NA_character_)
  }

  obj <- env_get(ns, topic, inherit = TRUE)
  ex_package <- find_reexport_source(obj, ns, topic)
  # Give up if we're stuck in an infinite loop
  if (package == ex_package) {
    return(NA_character_)
  }

  href_topic_remote(topic, ex_package)
}

find_reexport_source <- function(obj, ns, topic) {
  if (is.primitive(obj)) {
    # primitive functions all live in base
    "base"
  } else if (is.function(obj)) {
    ## For functions, we can just take their environment.
    ns_env_name(get_env(obj))
  } else {
    ## For other objects, we need to check the import env of the package,
    ## to see where 'topic' is coming from. The import env has redundant
    ## information. It seems that we just need to find a named list
    ## entry that contains `topic`.
    imp <- getNamespaceImports(ns)
    imp <- imp[names(imp) != ""]
    wpkgs <- vapply(imp, `%in%`, x = topic, FUN.VALUE = logical(1))

    if (!any(wpkgs)) {
      return(NA_character_)
    }
    pkgs <- names(wpkgs)[wpkgs]
    # Take the last match, in case imports have name clashes.
    pkgs[[length(pkgs)]]
  }
}

# Articles ----------------------------------------------------------------

#' @export
#' @rdname href_topic
href_article <- function(article, package = NULL) {
  if (is_package_local(package)) {
    path <- find_article(NULL, article)
    if (!is.null(path)) {
      return(paste0(getOption("downlit.article_path"), path))
    }
  }

  if (is.null(package)) {
    package <- find_vignette_package(article)
    if (is.null(package)) {
      return(NA_character_)
    }
  }

  path <- find_article(package, article)
  if (is.null(path)) {
    return(NA_character_)
  }

  base_url <- remote_package_article_url(package)
  if (!is.null(base_url)) {
    paste0(base_url, "/", path)
  } else if (is_bioc_pkg(package)) {
    paste0("https://bioconductor.org/packages/release/bioc/vignettes/", package, "/inst/doc/", path)
  } else {
    paste0("https://cran.rstudio.com/web/packages/", package, "/vignettes/", path)
  }
}

# Returns NA if package is not installed.
# Returns TRUE if `package` is from Bioconductor, FALSE otherwise
is_bioc_pkg <- function(package) {
  if (!rlang::is_installed(package)) {
    return(FALSE)
  }
  biocviews <- utils::packageDescription(package, fields = "biocViews")
  !is.na(biocviews) && biocviews != ""
}


# Try to figure out package name from attached packages
find_vignette_package <- function(x) {
  for (pkg in getOption("downlit.attached")) {
    if (!is_installed(pkg)) {
      next
    }

    info <- tools::getVignetteInfo(pkg)

    if (x %in% info[, "Topic"]) {
      return(pkg)
    }
  }

  NULL
}

# Packages ----------------------------------------------------------------

#' @export
#' @rdname href_topic
href_package <- function(package) {
  urls <- package_urls(package)
  if (length(urls) == 0) {
    NA_character_
  } else {
    urls[[1]]
  }
}

href_package_ref <- function(package) {
  reference_url <- remote_package_reference_url(package)

  if (!is.null(reference_url)) {
    reference_url
  } else {
    # Fall back to rdrr.io
    if (is_base_package(package)) {
      paste0("https://rdrr.io/r/", package)
    } else {
      paste0("https://rdrr.io/pkg/", package, "/man")
    }
  }
}

is_base_package <- function(x) {
  x %in% c(
    "base", "compiler", "datasets", "graphics", "grDevices", "grid",
    "methods", "parallel", "splines", "stats", "stats4", "tcltk",
    "tools", "utils"
  )
}
