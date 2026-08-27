accounts
--------
id
username
password_hash
created_at


characters
----------
id
account_id
name
map_id
x
y
money
created_at
last_seen


pokemon_instances
-----------------
id
character_id
species_id
level
experience
status_id
...custom mechanical fields...


pokemon_moves
-------------
pokemon_id
slot
move_id
pp
pp_max


inventory
---------
character_id
item_id
quantity