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

## Shiny image

Build the Shiny image from the local geocoder image:

```sh
container build \
  -f Containerfile.shiny \
  --build-arg ADDR_GEOCODER_BASE_IMAGE=addr_geocoder:local \
  --build-arg ADDR_GEOCODER_BASE_NAME=addr_geocoder:local \
  -t addr_geocoder_shiny:local \
  .
```

Run the app without input or output mounts:

```sh
container run --rm --memory 8g --cpus 4 \
  --publish 127.0.0.1:3838:3838 \
  --env SHINY_PORT=3838 \
  addr_geocoder_shiny:local
```

Open `http://127.0.0.1:3838`, upload `input/addresses.csv`, choose the options,
and click **Run geocoding**. The Workers field defaults to the four CPUs
allocated to the container. The output is downloaded through the browser.
