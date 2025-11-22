import os
import json

assets_path = "/Users/guo/Documents/iOS/KuaiJi/KuaiJi_IOSApp/KuaiJi/Assets.xcassets"

colors = {
    "BrandPrimary": {
        "light": "#7A4A2A",
        "dark": "#7A4A2A"
    },
    "Background": {
        "light": "#F6F2EE",
        "dark": "#0E0E11"
    },
    "Surface": {
        "light": "#FFFFFF",
        "dark": "#18181B"
    },
    "SurfaceAlt": {
        "light": "#FBF8F4",
        "dark": "#FBF8F4"
    },
    "TextPrimary": {
        "light": "#3A2B22",
        "dark": "#C9C7C4"
    },
    "SecondaryText": {
        "light": "#9C8F86",
        "dark": "#C9C7C4"
    },
    "LedgerContentText": {
        "light": "#3B291E",
        "dark": "#C9C7C4"
    },
    "Success": {
        "light": "#3BAF6A",
        "dark": "#3BAF6A"
    },
    "Danger": {
        "light": "#E56A5E",
        "dark": "#E56A5E"
    },
    "Info": {
        "light": "#7A93E0",
        "dark": "#7A93E0"
    },
    "Warning": {
        "light": "#FF9500",
        "dark": "#FF9500"
    },
    "ToggleOn": {
        "light": "#F5973C",
        "dark": "#F5973C"
    },
    "ToggleOff": {
        "light": "#E1D9D3",
        "dark": "#E1D9D3"
    },
    "Selection": {
        "light": "#007AFF",
        "dark": "#0A84FF"
    },
    "CardShadow": {
        "light": "#000000",
        "light_alpha": 0.06,
        "dark": "#FFFFFF",
        "dark_alpha": 0.06
    }
}

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def create_color_set(name, color_def):
    folder_path = os.path.join(assets_path, f"{name}.colorset")
    os.makedirs(folder_path, exist_ok=True)
    
    contents = {
        "colors": [],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    # Light Color (Any Appearance)
    light_hex = color_def["light"]
    r, g, b = hex_to_rgb(light_hex)
    alpha = color_def.get("light_alpha", 1.0)
    
    light_color = {
        "color": {
            "color-space": "srgb",
            "components": {
                "alpha": f"{alpha:.3f}",
                "blue": f"0x{b:02X}",
                "green": f"0x{g:02X}",
                "red": f"0x{r:02X}"
            }
        },
        "idiom": "universal"
    }
    
    # Dark Color
    dark_hex = color_def["dark"]
    r_d, g_d, b_d = hex_to_rgb(dark_hex)
    alpha_d = color_def.get("dark_alpha", 1.0)
    
    dark_color = {
        "appearances": [
            {
                "appearance": "luminosity",
                "value": "dark"
            }
        ],
        "color": {
            "color-space": "srgb",
            "components": {
                "alpha": f"{alpha_d:.3f}",
                "blue": f"0x{b_d:02X}",
                "green": f"0x{g_d:02X}",
                "red": f"0x{r_d:02X}"
            }
        },
        "idiom": "universal"
    }
    
    contents["colors"].append(light_color)
    contents["colors"].append(dark_color)
    
    with open(os.path.join(folder_path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

for name, definition in colors.items():
    create_color_set(name, definition)
    print(f"Created {name}.colorset")
