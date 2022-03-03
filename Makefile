.PHONY: test lint local build

test:
	busted

lint: build
	moonc -l lapis

local: build
	luarocks make --local --lua-version=5.1 lapis-annotate-dev-1.rockspec

build:
	moonc lapis