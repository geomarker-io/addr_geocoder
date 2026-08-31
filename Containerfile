ARG ADDR_BASE_IMAGE=ghcr.io/geomarker-io/addr:v2.0.0@sha256:bf43ff6d68b8889ecc517e6bf334a9af5a616cbb87c864145b6874ec040687f5
FROM ${ADDR_BASE_IMAGE}

ARG ADDR_BASE_NAME=ghcr.io/geomarker-io/addr:v2.0.0
ARG ADDR_BASE_DIGEST=sha256:bf43ff6d68b8889ecc517e6bf334a9af5a616cbb87c864145b6874ec040687f5
ARG ADDR_VERSION=2.0.0
ARG ADDR_RELEASE_TAG=v2.0.0
ARG TAF_SCHEMA=v2
ARG TAF_YEAR=2025
ARG BUILD_DATE
ARG VCS_REF
ARG IMAGE_VERSION=v2.0.0-taf-v2-2025

LABEL org.opencontainers.image.title="addr_geocoder" \
      org.opencontainers.image.description="addr-geocode CLI with the complete 2025 TAF v2 bundle" \
      org.opencontainers.image.source="https://github.com/geomarker-io/addr_geocoder" \
      org.opencontainers.image.url="https://github.com/geomarker-io/addr_geocoder" \
      org.opencontainers.image.documentation="https://github.com/geomarker-io/addr_geocoder#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.base.name="${ADDR_BASE_NAME}" \
      org.opencontainers.image.base.digest="${ADDR_BASE_DIGEST}" \
      io.addr.package.version="${ADDR_VERSION}" \
      io.addr.taf.schema="${TAF_SCHEMA}" \
      io.addr.taf.year="${TAF_YEAR}"

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The addr base image provides addr, stow, mirai, curl, and addr-geocode.
# These two utilities are required by addr's packaged TAF installer.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libdigest-sha-perl \
        zstd \
    && rm -rf /var/lib/apt/lists/*

ENV R_USER_DATA_DIR=/opt/addr-data

# Download, validate, install, and delete the compressed release assets in one
# layer. The packaged installer verifies the release metadata and checksum,
# every Parquet file, the installed manifest, a TAF lookup, and a geocode.
RUN set -eux; \
    Rscript -e "stopifnot(packageVersion('addr') == package_version('${ADDR_VERSION}'))"; \
    bundle_dir="$(mktemp -d)"; \
    trap 'rm -rf "$bundle_dir"' EXIT; \
    archive="addr-taf-${TAF_SCHEMA}-${TAF_YEAR}.tar.zst"; \
    metadata="addr-taf-${TAF_SCHEMA}-${TAF_YEAR}.json"; \
    release_base="https://github.com/geomarker-io/addr/releases/download/${ADDR_RELEASE_TAG}"; \
    curl --fail --location --silent --show-error --retry 3 \
      "${release_base}/${archive}" -o "${bundle_dir}/${archive}"; \
    curl --fail --location --silent --show-error --retry 3 \
      "${release_base}/${metadata}" -o "${bundle_dir}/${metadata}"; \
    installer="$(Rscript -e 'cat(system.file("exec", "install-addr-taf-fuel.sh", package = "addr", mustWork = TRUE))')"; \
    bash "${installer}" "${bundle_dir}/${archive}" "${bundle_dir}/${metadata}"; \
    rm -rf "${bundle_dir}"; \
    trap - EXIT; \
    chown -R root:root /opt/addr-data; \
    find /opt/addr-data -type d -exec chmod 0555 {} +; \
    find /opt/addr-data -type f -exec chmod 0444 {} +; \
    install -d -o root -g root -m 0555 /input; \
    install -d -o addr -g addr -m 0755 /output

ENV ADDR_TAF_SCHEMA=${TAF_SCHEMA} \
    ADDR_TAF_YEAR=${TAF_YEAR}

USER addr
WORKDIR /home/addr

RUN addr-geocode --help >/dev/null

ENTRYPOINT ["addr-geocode"]
CMD ["--help"]
