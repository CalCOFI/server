FROM rocker/geospatial:latest

# https://github.com/rocker-org/rocker-versioned2/tree/master/scripts
RUN /rocker_scripts/install_shiny_server.sh
RUN /rocker_scripts/install_python.sh

# https://github.com/CalCOFI/apps
#   https://github.com/CalCOFI/apps/blob/main/libs/db.R
#   https://github.com/CalCOFI/apps/blob/main/oceano/global.R
# https://github.com/CalCOFI/api/blob/main/plumber.R
# https://github.com/CalCOFI/SaferSeafood/blob/main/shinydashboard/global.R
RUN install2.r --error \
  brms bslib caret corrplot DBI dbplyr DiagrammeR digest DT extrafont \
  flexdashboard fs geojsonio geos glue gt here htmltools htmlwidgets httpuv httr2 jsonlite \
  kableExtra leaflet leaflet.extras librarian listviewer lubridate mapedit \
  mapview markdown plumber plotly png pool purrr raster Rcpp reactlog readr \
  reticulate rfishbase rhandsontable rmarkdown RPostgres sf shiny shinyBS \
  shinycssloaders shinydashboard shinyjs shinyWidgets showtext sjPlot skimr sp \
  stringr terra tibble tidymodels tidyr tidyverse units urltools webshot2 yaml \
 && rm -rf /tmp/downloaded_packages

# install R packages on Github 
RUN installGithub.r \
  CalCOFI/calcofi4r \
  oceanmetrics/leaftiles \
  && rm -rf /tmp/downloaded_packages
  
EXPOSE 3838  

# add users
COPY users.csv    /tmp/users.csv
COPY add_users.sh /tmp/add_users.sh
RUN chmod +x /tmp/add_users.sh && /tmp/add_users.sh

CMD ["/init"]