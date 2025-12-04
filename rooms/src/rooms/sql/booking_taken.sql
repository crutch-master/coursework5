select exists(
  select 1
  from bookings
  where room_id = $1
  and end_time > $2
  and start_time < $3
  and status = 'confirmed'
);
