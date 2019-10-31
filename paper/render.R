library(bookdown)
library(tinytex)
library(data.table)

if (file.exists('_main.Rmd'))
  file.remove('_main.Rmd')

#bookdown::render_book("paper.Rmd", "bookdown::pdf_book", clean = T)
#bookdown::render_book("paper.Rmd", "bookdown::word_document2", clean=T)
bookdown::render_book("paper.Rmd", "bookdown::html_document2", clean=T)

#tinytex::pdflatex('_book/thesis.tex')
#tinytex::pdflatex('thesis.tex')