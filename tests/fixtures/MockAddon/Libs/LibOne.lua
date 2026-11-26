-- Fixture library loaded through embeds.xml. Not shipped.
MockLibs = MockLibs or {}
MockLibs.one = (...) -- the addon name the loader passed
local _ = LibReadsNil -- a nil read inside Libs: the report leaves it out
