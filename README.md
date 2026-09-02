# addr_geocoder

This repository publishes two ready-to-run OCI images containing addr 2.0.0 and
the complete 2025 TAF v2 bundle:

- `addr_geocoder` runs the `addr-geocode` command.
- `addr_geocoder_shiny` provides a browser interface for uploading and
  downloading files.

Runtime TAF downloads are not required.

The upstream `ghcr.io/geomarker-io/addr:v2.0.0` image supports `linux/amd64`
and `linux/arm64`. The intended release tag is `v2.0.0-taf-v2-2025`.

## Pull with Apptainer

```sh
apptainer pull addr_geocoder_v2.0.0-taf-v2-2025.sif \
  docker://ghcr.io/geomarker-io/addr_geocoder:v2.0.0-taf-v2-2025
```

Show the command help:

```sh
apptainer run --cleanenv --contain \
  addr_geocoder_v2.0.0-taf-v2-2025.sif \
  --help
```

## Geocode a file

The input must be a CSV or Parquet file containing a column named exactly
`address`. Mount only that file read-only and mount a separate output directory:

```sh
mkdir -p output

apptainer run --cleanenv --contain \
  --bind "$PWD/input/addresses.csv:/input/addresses.csv:ro" \
  --bind "$PWD/output:/output" \
  addr_geocoder_v2.0.0-taf-v2-2025.sif \
  --input /input/addresses.csv \
  --output-dir /output \
  --workers 4
```

The published image is OCI-compatible, so other OCI runtimes can consume the
same GHCR image.

The output matches the input format and has a deterministic name containing the
image release tag and geocoding preset. For example, the current image writes
`address__addr-v2.0.0-taf-v2-2025__preset-default__geocoded.parquet` for an
input named `address.parquet`. Existing output is protected unless `--overwrite`
is supplied.

## Run the Shiny app

Pull the browser image:

```sh
apptainer pull addr_geocoder_shiny_v2.0.0-taf-v2-2025.sif \
  docker://ghcr.io/geomarker-io/addr_geocoder_shiny:v2.0.0-taf-v2-2025
```

Start the app with a chosen port. On LSF, forward the job's allocated processor
count through Apptainer's clean environment:

```sh
apptainer run --cleanenv --contain \
  --env SHINY_PORT=3838 \
  --env LSB_DJOB_NUMPROC="$LSB_DJOB_NUMPROC" \
  addr_geocoder_shiny_v2.0.0-taf-v2-2025.sif
```

Open `http://127.0.0.1:3838` when running locally. On a cluster, choose an
unused port and follow the cluster's instructions for tunneling that compute
node port. A typical tunnel created from the local computer looks like:

```sh
ssh -N -L 3838:COMPUTE_NODE:3838 USER@LOGIN_HOST
```

The app accepts one CSV or Parquet file containing a column named exactly
`address`. The worker count defaults to the CPUs available to the app from its
scheduler or container allocation and remains editable. Set
`ADDR_GEOCODE_WORKERS` only to override that detected default. Choose a
geocoding preset, click **Geocode**, watch the command progress, and click the
generated filename to download it. Browser upload and download require no bind
mounts. Files are temporary and are removed when the browser session ends.

## Versions

Both images pin addr 2.0.0 and TAF v2/2025. Both also set
`ADDR_GEOCODE_RELEASE_TAG` to the image release tag so CLI and browser downloads
use the same deterministic filename. The Shiny image installs the latest
available Shiny, processx, and parallelly packages during each release build.

The TAF tree is baked into `/opt/addr-data`, root-owned, and read-only. OCI
runtimes use the non-root `addr` user; Apptainer runs as the invoking host user.
The image is approximately 3.4 GB as stored, and converting it to a SIF requires
additional temporary cache space.

Images are built and published only when a GitHub release is published. The
workflow pins the upstream addr image digest and publishes both images for
`linux/amd64` and `linux/arm64`.
