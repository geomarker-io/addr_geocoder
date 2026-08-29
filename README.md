# addr_geocoder

`addr_geocoder` is a ready-to-run OCI image containing the `addr-geocode`
command, addr 2.0.0, and the complete 2025 TAF v2 bundle. Runtime downloads are
not required.

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
addr version and geocoding preset. Existing output is protected unless
`--overwrite` is supplied.

## Versions

This image pins addr 2.0.0, stow 0.3.0, and TAF v2/2025.

The TAF tree is baked into `/opt/addr-data`, root-owned, and read-only. OCI
runtimes use the non-root `addr` user; Apptainer runs as the invoking host user.
The image is approximately 3.4 GB as stored, and converting it to a SIF requires
additional temporary cache space.

Images are built and published only when a GitHub release is published. The
workflow pins the upstream addr image digest and verifies both architectures
before building.
