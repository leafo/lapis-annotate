# lapis-annotate

`lapis-annotate` is a [Lapis](http://leafo.net/lapis) extension that lets you
annotate your model files with their schema.


## Install

```
$ luarocks install lapis-annotate
```

## Usage

```
$ lapis annotate help
Usage: lapis annotate [-h] [--preload-module <name>]
       [--format {sql,table,generate_enum_comments}] [--print]
       <files> [<files>] ...

Extract schema information from model's table to comment model

Arguments:
   files                 Paths to model classes to annotate (eg. models/first.moon models/second.moon ...)

Options:
   -h, --help            Show this help message and exit.
   --preload-module <name>
                         Module to require before annotating a model
   --format {sql,table,generate_enum_comments}
                         What dump format to use (default: sql)
   --print, -p           Print the output instead of editing the model files

```

Example annotating a single model:


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

## Arguments

* `--preload-module=MODULE_NAME`: load the named module with `require` before initializing config

## Notes

Only supports MoonScript and PostgreSQL at the moment

## Changes

* **2021-03-15** `1.2.1` Don't include the default `public` table shema in output
* **2018-04-03** `1.2.0` Strip any `SELECT` lines from the output
* **2017-06-14** `1.1.0` Add support for db user/password (Skiouros), add shell escaping
* **2016-01-23** `1.0.0` Initial release
