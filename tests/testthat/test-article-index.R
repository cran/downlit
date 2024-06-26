test_that("NULL package uses context", {
  local_options("downlit.article_index" = c(a = "a"))
  expect_equal(article_index(NULL), c(a = "a"))
})

test_that("can capture index from in-development package", {
  local_devtools_package(test_path("index"))

  expect_equal(
    article_index("index"),
    c("test-1" = "test-1.html", "test-2" = "test-2.html")
  )

  expect_equal(find_article("index", "test-1"), "test-1.html")
  expect_equal(find_article("index", "missing"), NULL)
})

test_that("can capture index of installed package (no vignettes)", {
  skip_if_not_installed("MASS")
  # Ensure we skip this test if MASS ever gets vignettes
  skip_if_not(nrow(vignette(package = "MASS")$results) == 0)
  expect_equal(
    article_index("base"),
    character()
  )
})

test_that("can capture index of installed package (vignettes + pkgdown)", {
  # Requires internet + number of vignettes might change
  skip_on_cran()

  expect_true("custom-expectation.html" %in% article_index("testthat"))
})

test_that("can capture index of installed package (vignettes + pkgdown)", {
  n_vignettes <- nrow(vignette(package = "grid")$results)
  expect_length(article_index("grid"), n_vignettes)
})

# find_article ------------------------------------------------------------
