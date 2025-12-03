with rows as (
  update bookings
  set status = 'cancelled'
  where id = $1 and user_id = $2
  returning 1
)
select count(*) from rows;
