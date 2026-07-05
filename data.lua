data.raw["gui-style"]["default"]["gom_wide_textfield"] = {
  type = "textbox_style",
  parent = "textbox",
  minimal_width = 300
}

data.raw["gui-style"]["default"]["gom_tab_inactive"] = {
  type = "button_style",
  parent = "button",
  font = "default-bold",
  minimal_width = 80
}

data.raw["gui-style"]["default"]["gom_tab_active"] = {
  type = "button_style",
  parent = "button",
  font = "default-bold",
  minimal_width = 80,
  default_graphical_set = {
    base = {position = {34, 17}, corner_size = 8,
            filename = "__core__/graphics/gui.png", scale = 0.5}
  }
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
