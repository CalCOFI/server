# CalCOFI ERDDAP image: stock ERDDAP + the DuckDB JDBC driver.
#
# Why: the official erddap/erddap image bundles the PostgreSQL JDBC driver but
# NOT DuckDB's. EDDTableFromDatabase needs a JDBC driver to read DuckDB views
# over our partitioned Parquet (so ERDDAP streams filtered results instead of
# loading a whole Parquet file into the JVM heap, as EDDTableFromParquetFiles
# does — the OOM that disabled calcofi_ctd / ctd_wide).
# See CalCOFI/workflows/bench_erddap_ctd.qmd for the benchmark + rationale.
#
# Version pin (IMPORTANT): the duckdb_jdbc engine version must be >= (ideally
# equal to) the DuckDB engine that BUILT the .db file, or DuckDB refuses to open
# it ("database written by a newer DuckDB version"). We build the .db with
# DuckDB 1.5.2, so pin the JDBC jar to 1.5.2.x. Bump deliberately and rebuild
# the .db when changing this.

ARG ERDDAP_TAG=latest
FROM erddap/erddap:${ERDDAP_TAG}

ARG DUCKDB_JDBC_VERSION=1.5.2.1

# duckdb_jdbc is a fat jar that bundles the native library; nothing else to install.
ADD https://repo1.maven.org/maven2/org/duckdb/duckdb_jdbc/${DUCKDB_JDBC_VERSION}/duckdb_jdbc-${DUCKDB_JDBC_VERSION}.jar \
    /usr/local/tomcat/webapps/erddap/WEB-INF/lib/duckdb_jdbc-${DUCKDB_JDBC_VERSION}.jar

RUN chmod 644 /usr/local/tomcat/webapps/erddap/WEB-INF/lib/duckdb_jdbc-*.jar
