# App web + Caddy en una sola imagen. La API se sirve en el mismo origen
# (/api), así que la app no necesita saber el dominio al compilar.
FROM ghcr.io/cirruslabs/flutter:stable AS build
# El SDK de la imagen va por detrás del que pide pubspec.yaml (^3.13.4): se
# instala la versión exacta por encima.
ARG FLUTTER_VERSION=3.47.6
RUN git clone --depth 1 -b ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter-${FLUTTER_VERSION}
ENV PATH=/opt/flutter-${FLUTTER_VERSION}/bin:$PATH
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_BASE=origin

FROM caddy:2
COPY --from=build /app/build/web /srv
COPY Caddyfile tls-none.conf tls-internal.conf /etc/caddy/
