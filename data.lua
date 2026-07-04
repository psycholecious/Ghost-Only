data:extend({
  {
    type = "gui-style",
    name = "gom_wide_textfield",
    parent = "wide_textfield",
    minimal_width = 300
  },
  {
    type = "custom-input",
    name = "ghost-only-toggle",
    key_sequence = "CONTROL + G",
    consuming = "none",
    action = "lua"
  }
})
