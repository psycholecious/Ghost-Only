data.raw["gui-style"]["default"]["gom_wide_textfield"] = {
  type = "textbox_style",
  parent = "textbox",
  minimal_width = 300
}

data.raw["gui-style"]["default"]["gom_tab_inactive"] = {
  type = "button_style",
  parent = "button",
  font = "default-bold",
  minimal_width = 90,
  height = 28
}

data.raw["gui-style"]["default"]["gom_tab_active"] = {
  type = "button_style",
  parent = "button",
  font = "default-bold",
  minimal_width = 90,
  height = 28,
  default_font_color = {0.9, 0.7, 0.1},
}

data:extend({
  {
    type = "custom-input",
    name = "ghost-only-toggle",
    key_sequence = "CONTROL + G",
    consuming = "none",
    action = "lua"
  },
  {
    type = "custom-input",
    name = "ghost-only-settings",
    key_sequence = "CONTROL + SHIFT + G",
    consuming = "none",
    action = "lua"
  }
})
