-- saved variables edge cases: escapes, numbers, nesting, booleans
EdgeDB = {
	["plain"] = "a\"b\\c\n\r\t\a\b\f\v\0z",
	["dec"] = "\65\066\x41\z
	   end",
	["quote'"] = 'it\'s',
	["utf8"] = "caf\195\169 \226\130\172 \240\159\152\128 \195",
	["bad"] = "\128\255\224\130",
	["ctl"] = "\1\31\127",
	["long"] = [[line1
line2 "q" \n]],
	["long2"] = [==[a]]b]==],
	["ints"] = { 0, 1, -1, 42, 1e15, 999999999999999, 9007199254740993, 1e14 },
	["floats"] = { 0.5, -0.25, 3.14159265358979, 1e300, 1e-5, .5, 5., 1.5e3, 0x10, 0xff, 123456789.123456789, 100000000000000000000 },
	["flags"] = { true, false, true },
	nested = { a = { b = { c = { d = "deep", e = {} } } }, list = { { 1, 2 }, { 3, { 4 } } } },
	[1] = "one", [2] = "two", [2.5] = "frac", [true] = "t",
	mixed = { "x", y = "z", [3] = "w" },
	sparse = { [1] = "a", [3] = "c" },
	dup = { k = 1, k = 2 },
	gone = { a = nil, b = 1 },
	empty = {},
	-- comment
	--[[ long
	comment ]] after = "x";
	semi = { 1; 2; 3 },
}
EdgeText = "top level string"
EdgeNum = -7
EdgeFlag = false
EdgeNil = nil
