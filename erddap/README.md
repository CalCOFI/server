# Custom CalCOFI ERDDAP image

`erddap/erddap:latest` + the **DuckDB JDBC driver** (`duckdb_jdbc`), so ERDDAP can
serve large tables via `EDDTableFromDatabase` over DuckDB views of partitioned
Parquet — streaming filtered results instead of loading whole Parquet files into
the JVM heap (`EDDTableFromParquetFiles`'s behaviour, which OOM'd `ctd_wide`).

## Build

```bash
docker build -t calcofi-erddap:duckdb \
  --build-arg DUCKDB_JDBC_VERSION=1.5.2.1 \
  /share/github/CalCOFI/server/erddap
```

## Version pinning

`DUCKDB_JDBC_VERSION` must be **>= the DuckDB engine that built the `.db`** (we
build with DuckDB 1.5.2 → pin `1.5.2.x`). A newer-format `.db` cannot be opened
by an older engine. On any bump, rebuild the `.db` (see
`CalCOFI/workflows/libs/erddap_duckdb.R`) and record the engine in its
`BUILD_VERSION.txt`.

## Benchmark / bench instance

The benchmark that justified this lives in `CalCOFI/workflows/bench_erddap_ctd.qmd`
and runs an isolated second ERDDAP via `../docker-compose.bench.yml` (port 8091),
leaving live `erddap` on 8090 untouched.
