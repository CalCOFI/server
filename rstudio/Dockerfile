FROM rocker/geospatial:latest

# https://github.com/rocker-org/rocker-versioned2/tree/master/scripts
RUN /rocker_scripts/install_shiny_server.sh
RUN /rocker_scripts/install_python.sh

EXPOSE 3838

RUN install2.r --error \
  dbplyr \
  DiagrammeR \
  DT \
  flexdashboard \
  fs \
  glue \
  gt \
  here \
  htmltools \
  httpuv \
  jsonlite \
  kableExtra \
  leaflet \
  librarian \
  mapedit \
  mapview \
  plumber \
  Rcpp \
  reticulate \
  rhandsontable \
  RPostgres \
  shinydashboard \
  shinyjs \
  shinyWidgets \
  units \
  urltools

CMD ["/init"]