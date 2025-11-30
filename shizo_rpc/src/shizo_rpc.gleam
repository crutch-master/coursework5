import gleam/dynamic/decode
import gleam/json

pub type Codec(a) {
  Codec(encode: fn(a) -> json.Json, decoder: decode.Decoder(a))
}

pub type Procedure(req, res) {
  Procedure(name: String, req_codec: Codec(req), res_codec: Codec(res))
}

pub type Handler(deps, req, res) {
  Handler(procedure: Procedure(req, res), handler: fn(deps, req) -> res)
}
