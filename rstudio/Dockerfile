FROM rocker/geospatial:latest

# https://github.com/rocker-org/rocker-versioned2/tree/master/scripts
RUN /rocker_scripts/install_shiny_server.sh
RUN /rocker_scripts/install_python.sh

# https://github.com/CalCOFI/apps
#   https://github.com/CalCOFI/apps/blob/main/libs/db.R
#   https://github.com/CalCOFI/apps/blob/main/oceano/global.R
# https://github.com/CalCOFI/api/blob/main/plumber.R
# https://github.com/CalCOFI/SaferSeafood/blob/main/shinydashboard/global.R
# knitr + xfun are listed explicitly so they install at latest in lock-step:
#   xfun renamed attr()->attr2(), and a stale transitive knitr that still did
#   importFrom(xfun, attr) broke skimr/SaferSeafood (uptime #1, 2026-06-08).
# googleCloudStorageR + gridExtra are required by the 2026-ucsb-larvae-dashboard
#   (preliminaryanalysis/dashboard/app.R required_pkgs); ggplot2 + RColorBrewer
#   are listed explicitly there too (otherwise only pulled in transitively via
#   tidyverse). webshot2 needs a headless Chrome, installed below.
RUN install2.r --error \
  brms bslib caret corrplot DBI dbplyr DiagrammeR digest dplyr DT extrafont \
  bsicons conductor data.tree duckdb geosphere highcharter litedown MBA shinyjqui thematic \
  knitr xfun \
  firebase flexdashboard fs geojsonio geos ggplot2 glue googleCloudStorageR gridExtra gt here htmltools htmlwidgets httpuv httr2 jsonlite \
  kableExtra leaflet leaflet.extras librarian listviewer lubridate mapedit \
  mapview markdown plumber plotly png pool purrr rapport raster RColorBrewer Rcpp reactlog readr \
  reticulate rfishbase rhandsontable ritis rmarkdown rnaturalearth rnaturalearthhires rpostgis RPostgres scales sf shiny shinyBS \
  shinycssloaders shinydashboard shinyjs shinyWidgets showtext shinythemes sjPlot skimr sp \
  stringr terra tibble tidymodels tidyr tidyverse units urltools viridis webshot2 yaml \
 && rm -rf /tmp/downloaded_packages

# install R packages on Github
#   bbest/mapgl@feat/add-h3t-source: int-app sets H3T_USE=TRUE and needs the
#   h3t tile source from this fork branch (PR #199); also a superset of CRAN
#   mapgl, so it covers datacheck + ctd-viz too.
RUN installGithub.r \
  CalCOFI/calcofi4r \
  oceanmetrics/leaftiles \
  dreamRs/shinyWidgets \
  dreamRs/shinytreeview \
  bbest/mapgl@feat/add-h3t-source \
  qfes/rdeck \
  && rm -rf /tmp/downloaded_packages

# Headless Google Chrome for webshot2/chromote. The dashboard PDF export renders
# the Spatial Distribution leaflet map via webshot2::webshot(), which drives a
# headless browser through chromote; without a browser it fails with
# "Chrome must be installed to include the Spatial Distribution map in PDF exports."
# rocker/geospatial (Ubuntu) ships no browser, and Ubuntu's `chromium` is a snap
# stub that won't run in a container, so install Google Chrome stable from its
# .deb (apt resolves its runtime deps). CHROMOTE_CHROME points chromote at it.
RUN apt-get update \
  && apt-get install -y --no-install-recommends wget gnupg ca-certificates \
  && wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
  && rm -f /tmp/google-chrome.deb \
  && rm -rf /var/lib/apt/lists/*
ENV CHROMOTE_CHROME=/usr/bin/google-chrome

# Fail the build loudly if Chrome is broken, rather than discovering it at PDF-
# export time. Checks the binary runs and that chromote (used by webshot2) can
# locate it.
RUN google-chrome --version \
  && Rscript -e 'if (!nzchar(chromote::find_chrome())) quit(status = 1)'

ARG PASSWORD

EXPOSE 3838  

# add users
COPY users.csv    /tmp/users.csv
COPY add_users.sh /tmp/add_users.sh
RUN chmod +x /tmp/add_users.sh && PASSWORD=$PASSWORD && /tmp/add_users.sh

# enforce permissions
RUN chgrp -R staff /share/github && chmod -R g+w /share/github

CMD ["/init"]