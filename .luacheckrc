std = "lua54"
globals = {
  "vim",
}
max_line_length = false

files["lua/vimteacher/lessons/*.lua"] = {
  ignore = {
    "212",
  },
}
