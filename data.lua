data.raw["gui-style"]["default"]["gom_wide_textfield"] = {
  type = "textbox_style",
  parent = "textbox",
  minimal_width = 300
}

data:extend({
  {
    type = "custom-input",
    name = "ghost-only-toggle",
    key_sequence = "CONTROL + G",
    consuming = "none",
    action = "lua"
  }
})
