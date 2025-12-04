import api/web
import wisp

pub fn handle_request(req: wisp.Request, ctx: web.Context) -> wisp.Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["user", "create"] -> web.create_user(req, ctx)
    ["user", "login"] -> web.login(req, ctx)
    ["user", "get"] -> web.get_user(req, ctx)
    ["rooms", "get"] -> web.get_rooms(req, ctx)
    ["bookings", "get"] -> web.get_bookings(req, ctx)
    ["bookings", "my"] -> web.get_user_bookings(req, ctx)
    ["bookings", "place"] -> web.place_booking(req, ctx)
    ["bookings", "cancel"] -> web.cancel_booking(req, ctx)
    _ -> wisp.not_found()
  }
}
