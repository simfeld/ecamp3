#syntax=docker/dockerfile:1

# Production-style Keycloak image with the eCamp User Storage SPI (validates password
# logins live against eCamp's own API, see spi/ecamp-user-storage/) and the eCamp login
# theme (see themes/ecamp/) baked in via `kc.sh build` at image build time.
#
# Unlike local dev's docker-compose `keycloak` service (`start-dev`, which re-augments on
# every boot and volume-mounts the SPI jar/theme live -- explicitly not for production use,
# per Keycloak's own startup warning), this image is meant to be pre-built and immutable,
# matching what the Keycloak Operator's `Keycloak` CR expects when given a custom image
# (a custom image skips the Operator's own build-time augmentation entirely).
#
# Storage/DB configuration is deliberately left to runtime env vars / Operator CR fields,
# not baked in here -- keeps this image usable regardless of what the target cluster's
# database setup ends up being.

FROM maven:3.9-eclipse-temurin-21 AS spi-builder
WORKDIR /build
COPY spi/ecamp-user-storage/pom.xml .
COPY spi/ecamp-user-storage/src ./src
RUN mvn --batch-mode package

FROM quay.io/keycloak/keycloak:26.0 AS builder
COPY --from=spi-builder /build/target/ecamp-user-storage-spi.jar /opt/keycloak/providers/
COPY themes/ecamp /opt/keycloak/themes/ecamp
RUN /opt/keycloak/bin/kc.sh build --health-enabled=true --db=postgres --http-relative-path=/keycloak --http-management-relative-path=/

FROM quay.io/keycloak/keycloak:26.0
COPY --from=builder /opt/keycloak/ /opt/keycloak/
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
