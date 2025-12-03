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
where start_time between $1 and $2
and room_id = $3
and status = 'confirmed';
