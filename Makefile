.PHONY: all build test

swift_flags := -Xcc -fdeclspec

pwd := $(shell pwd)

all: build

build:
	PKG_CONFIG_PATH=${pwd}/Packages/CRuby swift build ${swift_flags}

test:
	PKG_CONFIG_PATH=${pwd}/Packages/CRuby swift test ${swift_flags}

