# lapis-annotate

`lapis-annotate` is a [Lapis](http://leafo.net/lapis) extension that lets you
annotate your model files with their schema.


## Install

```
$ luarocks install lapis-annotate
```

## Usage

```
$ lapis annotate models/my_model.moon
```

Before: 

```moon
import Model from require "lapis.db.model"

class UserIpAddresses extends Model
  @timestamp: true
  @primary_key: {"user_id", "ip"}
```

After:


```moon
import Model from require "lapis.db.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE user_ip_addresses (
--   user_id integer NOT NULL,
--   ip character varying(255) NOT NULL,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY user_ip_addresses
--   ADD CONSTRAINT user_ip_addresses_pkey PRIMARY KEY (user_id, ip);
-- CREATE INDEX user_ip_addresses_ip_idx ON user_ip_addresses USING btree (ip);
--
class UserIpAddresses extends Model
  @timestamp: true
  @primary_key: {"user_id", "ip"}


```

## Notes

Only supports MoonScript and PostgreSQL at the moment



