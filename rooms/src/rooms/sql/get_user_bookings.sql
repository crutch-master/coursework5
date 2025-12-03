select
  bookings.id,
  users.name as user_name,
  rooms.id as room_id,
  rooms.name as room_name,
  rooms.details,
  bookings.start_time,
  bookings.end_time
from bookings
inner join users on bookings.user_id = users.id
inner join rooms on bookings.room_id = rooms.id
where user_id = $1;
