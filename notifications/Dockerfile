from ghcr.io/gleam-lang/gleam:v1.13.0-scratch as gleam

from erlang:28-alpine as build
copy --from=gleam /bin/gleam /bin/gleam
copy ./notifications /app/
run cd /app && gleam export erlang-shipment

from erlang:28-alpine
copy --from=build /app/build/erlang-shipment /app
workdir /app
expose 3000
entrypoint ["/app/entrypoint.sh"]
cmd ["run"]
