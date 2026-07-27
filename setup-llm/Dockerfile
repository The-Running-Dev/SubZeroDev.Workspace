# syntax=docker/dockerfile:1.7

FROM node:20-bookworm-slim AS docs-build

ARG POWERSHELL_VERSION=7.4.12

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl \
    && architecture="$(dpkg --print-architecture)" \
    && curl --fail --location --silent --show-error \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell_${POWERSHELL_VERSION}-1.deb_${architecture}.deb" \
        --output /tmp/powershell.deb \
    && apt-get install --yes --no-install-recommends /tmp/powershell.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/powershell.deb

WORKDIR /opt/workspace
COPY setup-llm ./setup-llm
COPY README.md ./README.md
COPY docs-template ./docs-template

RUN corepack enable \
    && pwsh -NoLogo -NoProfile -File ./setup-llm/scripts/setup-docs.ps1 \
    && cd docs-template \
    && HUSKY=0 pnpm install --frozen-lockfile \
    && HUSKY=0 NODE_ENV=production pnpm run build:prod

FROM node:20-bookworm-slim AS runtime-base

ARG POWERSHELL_VERSION=7.4.12

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl docker.io git nginx sudo \
    && architecture="$(dpkg --print-architecture)" \
    && curl --fail --location --silent --show-error \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell_${POWERSHELL_VERSION}-1.deb_${architecture}.deb" \
        --output /tmp/powershell.deb \
    && apt-get install --yes --no-install-recommends /tmp/powershell.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/powershell.deb /var/www/html/*

WORKDIR /opt/workspace
COPY setup-llm ./setup-llm
COPY README.md ./README.md
COPY setup-llm/entrypoint.ps1 ./entrypoint.ps1

VOLUME ["/workspace", "/root/.config"]
EXPOSE 8080

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "/opt/workspace/entrypoint.ps1"]
CMD ["docs"]

FROM runtime-base AS runtime-prebuilt
COPY docs-template/artifacts /var/www/html

FROM runtime-base AS runtime
COPY --from=docs-build /opt/workspace/docs-template/artifacts /var/www/html
