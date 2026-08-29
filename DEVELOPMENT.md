# Local development

These commands use Apple container on macOS to build and run the image locally.

Start the container service and build the image:

```sh
container system start
container build \
  -f Containerfile \
  -t addr_geocoder:local \
  .
```

Apple container bind-mounts directories, so place the test CSV or Parquet file
in `input/` and create a separate output directory:

```sh
mkdir -p input output

container run --rm --memory 8g \
  --mount type=bind,source="$PWD/input",target=/input,readonly \
  --mount type=bind,source="$PWD/output",target=/output \
  addr_geocoder:local \
  --input /input/addresses.csv \
  --output-dir /output \
  --workers 4
```

The 8 GB allocation is appropriate for the included 10,000-address example
with four workers; Apple container's default 1 GB allocation is insufficient
for that run. Add `--overwrite` to the `addr-geocode` arguments when replacing
an existing output file.
