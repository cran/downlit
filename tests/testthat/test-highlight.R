test_that("can link to external topics that use ::", {
  local_options(
    "downlit.package" = "test",
    "downlit.topic_index" = c(foo = "bar")
  )

  verify_output(test_path("test-highlight.txt"), {
    "explicit package"
    cat(highlight("MASS::addterm()"))
    cat(highlight("MASS::addterm"))
    cat(highlight("?MASS::addterm"))

    "implicit package"
    cat(highlight("library(MASS)"))
    cat(highlight("addterm()"))
    cat(highlight("median()")) # base

    "local package"
    cat(highlight("test::foo()"))

    "operators / special syntax"
    cat(highlight("1 + 2 * 3"))
    cat(highlight("x %in% y"))
    cat(highlight("if (FALSE) 1"))
    cat(highlight("f <- function(x = 'a') {}"))

    "ansi escapes + unicode"
    cat(highlight("# \033[34mblue\033[39m"))
  })
})

test_that("unicode is not mangled", {
  skip_on_os("windows")

  expect_equal(highlight("# \u2714"), "<span class='c'># \u2714</span>")
})

test_that("distinguish logical and numeric",{
  expect_equal(highlight("TRUE"), "<span class='kc'>TRUE</span>")
  expect_equal(highlight("FALSE"), "<span class='kc'>FALSE</span>")
  expect_equal(highlight("1"), "<span class='m'>1</span>")
})
test_that("can parse code with carriage returns", {
  lines <- strsplit(highlight("1\r\n2"), "\n")[[1]]

  expect_equal(lines[[1]], "<span class='m'>1</span>")
  expect_equal(lines[[2]], "<span class='m'>2</span>")
})

test_that("syntax can span multiple lines", {
  expect_equal(highlight("f(\n\n)"), "<span class='nf'>f</span><span class='o'>(</span>\n\n<span class='o'>)</span>")
  expect_equal(highlight("'\n\n'"), "<span class='s'>'\n\n'</span>")
})

test_that("code with tab is not mangled", {
  expect_equal(highlight("\tf()"), "  <span class='nf'>f</span><span class='o'>(</span><span class='o'>)</span>")
  expect_equal(highlight("'\t'"), "<span class='s'>'  '</span>")
})

test_that("unparsable code returns NULL", {
  expect_equal(highlight("<"), NA_character_)
  # but pure comments still highlighted
  expect_equal(
    highlight("#"),
    "<span class='c'>#</span>"
  )
})

test_that("R6 methods don't get linked", {
  expect_equal(
    highlight("x$get()"),
    "<span class='nv'>x</span><span class='o'>$</span><span class='nf'>get</span><span class='o'>(</span><span class='o'>)</span>"
  )

  expect_equal(
    highlight("x$library()"),
    "<span class='nv'>x</span><span class='o'>$</span><span class='kr'>library</span><span class='o'>(</span><span class='o'>)</span>"
  )

})

test_that("R6 instantiation gets linked", {
  expect_equal(
    highlight("mean$new()"),
    "<span class='nv'><a href='https://rdrr.io/r/base/mean.html'>mean</a></span><span class='o'>$</span><span class='nf'>new</span><span class='o'>(</span><span class='o'>)</span>"
  )
  # But not new itself
  expect_equal(
    highlight("new()"),
    "<span class='nf'>new</span><span class='o'>(</span><span class='o'>)</span>"
  )
})

test_that("ansi escapes are converted to html", {
  expect_snapshot_output(highlight("# \033[31mhello\033[m"))
  expect_snapshot_output(highlight("# \u2029[31mhello\u2029[m"))
})
