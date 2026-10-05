# App web + Caddy en una sola imagen. La API se sirve en el mismo origen
# (/api), así que la app no necesita saber el dominio al compilar.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM caddy:2
COPY --from=build /app/build/web /srv
COPY Caddyfile /etc/caddy/Caddyfile
