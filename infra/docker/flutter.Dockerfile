FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

COPY apps/client/pubspec.yaml apps/client/pubspec.lock ./
RUN flutter pub get

COPY apps/client .
RUN flutter build web

FROM nginx:alpine

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
