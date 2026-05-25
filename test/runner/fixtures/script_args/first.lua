local CLI_ARGS = table.pack(...)

assert(CLI_ARGS.n == 3)
assert(CLI_ARGS[1] == "1")
assert(CLI_ARGS[2] == "testString")
assert(CLI_ARGS[3] == "123")

return "first"
