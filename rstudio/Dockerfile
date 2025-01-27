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
  brms bslib caret corrplot DBI dbplyr DiagrammeR digest dplyr DT extrafont \
  firebase flexdashboard fs geojsonio geos glue gt here htmltools htmlwidgets httpuv httr2 jsonlite \
  kableExtra leaflet leaflet.extras librarian listviewer lubridate mapedit \
  mapview markdown plumber plotly png pool purrr rapport raster Rcpp reactlog readr \
  reticulate rfishbase rhandsontable ritis rmarkdown rpostgis RPostgres scales sf shiny shinyBS \
  shinycssloaders shinydashboard shinyjs shinyWidgets showtext shinythemes sjPlot skimr sp \
  stringr terra tibble tidymodels tidyr tidyverse units urltools viridis webshot2 yaml \
 && rm -rf /tmp/downloaded_packages

# install R packages on Github 
RUN installGithub.r \
  CalCOFI/calcofi4r \
  oceanmetrics/leaftiles \
  dreamRs/shinyWidgets \
  dreamRs/shinytreeview \
  && rm -rf /tmp/downloaded_packages
  
ARG PASSWORD

EXPOSE 3838  

# add users
COPY users.csv    /tmp/users.csv
COPY add_users.sh /tmp/add_users.sh
RUN chmod +x /tmp/add_users.sh && PASSWORD=$PASSWORD && /tmp/add_users.sh

CMD ["/init"]