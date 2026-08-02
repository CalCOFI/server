# https://www.rplumber.io/articles/hosting.html#docker:~:text=FROM%20rstudio/plumber
# https://github.com/rstudio/plumber/blob/main/Dockerfile
# https://github.com/rocker-org/rocker-versioned2/blob/master/dockerfiles/geospatial_4.4.1.Dockerfile
FROM rocker/geospatial:latest

# install system dependencies
#   plumber deps; `rm` call removes `apt` cache; libpq RPostgres dep
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  curl git-core libssl-dev libcurl4-gnutls-dev libsodium-dev libxml2-dev \
  libpq-dev && rm -rf /var/lib/apt/lists/*

# install R packages on CRAN; `rm` call removes install2.r's cache
# per R libaries in https://github.com/CalCOFI/api/blob/main/plumber.R
RUN install2.r --error \
 DBI dbplyr digest dplyr DT fs glue gstat here httr2 jsonlite librarian lubridate \
 markdown plumber pool purrr raster rmarkdown RPostgres plotly readr shiny sf \
 stringr tibble tidyr yaml \
 && rm -rf /tmp/downloaded_packages

# install R packages on Github 
RUN installGithub.r \
  CalCOFI/calcofi4r \
#  r-lib/gargle \
  && rm -rf /tmp/downloaded_packages/

EXPOSE 8888

# The api repo moved to /share/github/CalCOFI/api in the July 2026 repo
# reorganization; this path kept the pre-move location and the container has been
# crash-looping ever since ("cannot open file '/share/github/api/run-api.R'"),
# restarting every few seconds under `restart: unless-stopped`.
CMD Rscript /share/github/CalCOFI/api/run-api.R

