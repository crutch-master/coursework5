import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/otp/actor
import gleam/result
import mug
import shizo_rpc

const read_timeout_ms = 1000

const size_bytes = 2

const req_id_bytes = 2

type ClientState {
  ClientState(
    counter: Int,
    replies: dict.Dict(BitArray, process.Subject(Result(BitArray, Nil))),
    socket: mug.Socket,
  )
}

type Message {
  Send(
    method: String,
    data: BitArray,
    deadline: process.Subject(Message),
    reply: process.Subject(Result(BitArray, Nil)),
  )
  Recieve(req_id: BitArray, data: BitArray)
  Deadline(req_id: BitArray)
  Stop
}

type CallErr {
  ReadErr
  MugErr(mug.Error)
}

pub type ConnErr {
  MugConnErr(mug.ConnectError)
  ActorErr(actor.StartError)
}

pub opaque type Client {
  Client(actor: actor.Started(process.Subject(Message)))
}

pub fn new_client(host, port) {
  use socket <- result.try(
    mug.new(host, port)
    |> mug.connect
    |> result.map_error(MugConnErr),
  )

  use actor <- result.try(
    actor.new(ClientState(counter: 0, replies: dict.new(), socket:))
    |> actor.on_message(on_message)
    |> actor.start
    |> result.map_error(ActorErr),
  )

  process.spawn(fn() { read_loop(socket, actor) })

  Ok(Client(actor))
}

pub fn call(
  client: Client,
  procedure: shizo_rpc.Procedure(req, resp),
  request: req,
) -> Result(resp, Nil) {
  use payload <- result.try(
    process.call_forever(client.actor.data, Send(
      method: procedure.name,
      data: procedure.req_codec.encode(request)
        |> json.to_string
        |> bit_array.from_string,
      deadline: client.actor.data,
      reply: _,
    )),
  )

  payload
  |> json.parse_bits(procedure.res_codec.decoder)
  |> result.map_error(fn(_) { Nil })
}

fn read_precise(sock, bytes) -> Result(BitArray, CallErr) {
  use bits <- result.try(case mug.receive_exact(sock, bytes, read_timeout_ms) {
    Ok(bits) -> Ok(bits)
    Error(mug.Timeout) -> read_precise(sock, bytes)
    Error(e) -> Error(MugErr(e))
  })

  case bit_array.byte_size(bits) == bytes {
    True -> Ok(bits)
    False -> Error(ReadErr)
  }
}

fn read_loop(socket, actor: actor.Started(process.Subject(Message))) {
  let read = {
    use req_id <- result.try(read_precise(socket, req_id_bytes))
    use size_bits <- result.try(read_precise(socket, size_bytes))
    let assert <<size:size({ size_bytes * 8 })>> = size_bits
    use payload_bits <- result.try(read_precise(socket, size))

    Ok(#(req_id, payload_bits))
  }

  case read {
    Ok(#(req_id, payload_bits)) -> {
      actor.send(actor.data, Recieve(req_id, payload_bits))
      read_loop(socket, actor)
    }
    Error(err) -> {
      actor.send(actor.data, Stop)
      echo err
    }
  }
}

fn on_message(
  state: ClientState,
  message: Message,
) -> actor.Next(ClientState, Message) {
  case message {
    Send(method, data, deadline, reply) -> {
      let req_id = <<state.counter:size({ req_id_bytes * 8 })>>
      process.send_after(deadline, read_timeout_ms, Deadline(req_id:))

      case
        method
        |> bit_array.from_string
        |> crypto.hash(crypto.Md5, _)
        |> bytes_tree.from_bit_array
        |> bytes_tree.append(req_id)
        |> bytes_tree.append(<<
          bit_array.byte_size(data):size({ size_bytes * 8 }),
        >>)
        |> bytes_tree.append(data)
        |> bytes_tree.to_bit_array
        |> mug.send(state.socket, _)
      {
        Ok(_) ->
          actor.continue(ClientState(
            counter: { state.counter + 1 }
              % { int.bitwise_shift_left(1, req_id_bytes * 8) },
            replies: dict.insert(state.replies, req_id, reply),
            socket: state.socket,
          ))
        Error(err) -> {
          echo err
          actor.stop()
        }
      }
    }
    Recieve(req_id, payload) -> {
      case dict.get(state.replies, req_id) {
        Ok(subj) -> actor.send(subj, Ok(payload))
        _ -> Nil
      }

      actor.continue(ClientState(
        counter: state.counter,
        replies: dict.delete(state.replies, req_id),
        socket: state.socket,
      ))
    }
    Deadline(req_id) -> {
      case dict.get(state.replies, req_id) {
        Ok(subj) -> actor.send(subj, Error(Nil))
        _ -> Nil
      }

      actor.continue(ClientState(
        counter: state.counter,
        replies: dict.delete(state.replies, req_id),
        socket: state.socket,
      ))
    }
    Stop -> {
      state.replies
      |> dict.fold(Nil, fn(_, _, reply) { actor.send(reply, Error(Nil)) })

      actor.stop()
    }
  }
}
