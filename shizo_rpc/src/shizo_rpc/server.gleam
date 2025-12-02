import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dict
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/result
import glisten/socket
import glisten/tcp
import shizo_rpc

const size_bytes = 2

const req_id_bytes = 2

const method_hash_bytes = 16

type TcpErr {
  ReadErr
  NoHandler
  SocketErr(socket.SocketReason)
  DecodeErr(json.DecodeError)
}

type TcpHandlerFn =
  fn(socket.Socket, BitArray) -> Result(Nil, TcpErr)

pub opaque type TcpHandler {
  TcpHandler(hash: BitArray, handler: TcpHandlerFn)
}

fn read_precise(sock, bytes) -> Result(BitArray, TcpErr) {
  use bits <- result.try(
    tcp.receive(sock, bytes)
    |> result.map_error(SocketErr),
  )

  case bit_array.byte_size(bits) == bytes {
    True -> Ok(bits)
    False -> Error(ReadErr)
  }
}

pub fn to_tcp_handler(h: shizo_rpc.Handler(deps, req, resp), deps: deps) {
  let hash =
    h.procedure.name
    |> bit_array.from_string
    |> crypto.hash(crypto.Md5, _)

  TcpHandler(hash: hash, handler: fn(sock, req_id) {
    use size_bits_arr <- result.try(read_precise(sock, size_bytes))
    let assert <<size:size({ size_bytes * 8 })>> = size_bits_arr

    use payload_bits <- result.try(read_precise(sock, size))

    use payload <- result.try(
      payload_bits
      |> json.parse_bits(h.procedure.req_codec.decoder)
      |> result.map_error(DecodeErr),
    )

    process.spawn(fn() {
      let resp =
        h.handler(deps, payload)
        |> h.procedure.res_codec.encode
        |> json.to_string
        |> bit_array.from_string

      bytes_tree.from_bit_array(req_id)
      |> bytes_tree.append(<<
        bit_array.byte_size(resp):size({ size_bytes * 8 }),
      >>)
      |> bytes_tree.append(resp)
      |> tcp.send(sock, _)
    })

    Ok(Nil)
  })
}

fn handle_conn(handlers, conn) {
  let res = {
    use hash <- result.try(read_precise(conn, method_hash_bytes))
    use handler <- result.try(
      dict.get(handlers, hash)
      |> result.map_error(fn(_) { NoHandler }),
    )

    use req_id <- result.try(read_precise(conn, req_id_bytes))
    use _ <- result.try(handler(conn, req_id))

    Ok(Nil)
  }

  case res {
    Error(e) -> {
      echo e
      tcp.close(conn)
    }
    _ -> handle_conn(handlers, conn)
  }
}

fn loop(handlers_map, sock) {
  use conn <- result.try(tcp.accept(sock))
  process.spawn(fn() { handle_conn(handlers_map, conn) })

  loop(handlers_map, sock)
}

pub fn start(handlers, sock) {
  let handlers_map =
    handlers
    |> list.map(fn(h: TcpHandler) { #(h.hash, h.handler) })
    |> dict.from_list

  loop(handlers_map, sock)
}
