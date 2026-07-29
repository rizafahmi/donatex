#!/usr/bin/env python3
"""Decode a QR code with OpenCV on behalf of the Elixir test suite.

Reads a single JSON argument describing the image to decode and prints a JSON
result on stdout. Two input shapes are supported:

  {"kind": "raw",  "path": "...", "width": W, "height": H}
  {"kind": "file", "path": "..."}

A raw input is a headerless RGB8 buffer, which lets Elixir hand pixels straight
to OpenCV without depending on an image encoder or an SVG rasteriser.

Optional keys:

  "margin": true   also run a degradation ladder (downscale + blur + contrast
                   reduction) and report how far the code survives. This is the
                   difference between "decodes in a pristine screenshot" and
                   "decodes from a phone camera pointed at a stream".
"""

import json
import sys

import cv2
import numpy as np


def load(spec):
    if spec["kind"] == "raw":
        buf = np.fromfile(spec["path"], dtype=np.uint8)
        expected = spec["height"] * spec["width"] * 3
        if buf.size != expected:
            raise ValueError(f"expected {expected} bytes, got {buf.size}")
        rgb = buf.reshape((spec["height"], spec["width"], 3))
        return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    img = cv2.imread(spec["path"], cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"could not read image at {spec['path']}")
    return img


def decode(img):
    value, _points, _straight = cv2.QRCodeDetector().detectAndDecode(img)
    return value or None


# Smallest rendered width (px) we probe down to. A QR that still decodes after
# being squeezed this small has room to spare at full size.
DOWNSCALE_LADDER = [320, 260, 200, 160, 130, 110, 90, 70]
BLUR_LADDER = [0, 3, 5, 7, 9, 11, 13]
# Multiplicative contrast reduction toward mid grey: 1.0 is untouched.
CONTRAST_LADDER = [1.0, 0.7, 0.5, 0.35, 0.25, 0.15, 0.1]


def smallest_decodable(img, expected):
    """Smallest width still decodable *without a gap* on the way down.

    Walking the ladder and keeping any width that happened to work overstates
    the margin badly: a render that fails at full size can start decoding again
    once downscaling averages the decoration away. Only an unbroken run from
    the top is evidence.
    """
    best = None
    for width in DOWNSCALE_LADDER:
        scaled = cv2.resize(img, (width, width), interpolation=cv2.INTER_AREA)
        if decode(scaled) != expected:
            break
        best = width
    return best


def blurriest_decodable(img, expected):
    best = None
    for ksize in BLUR_LADDER:
        blurred = img if ksize == 0 else cv2.GaussianBlur(img, (ksize, ksize), 0)
        if decode(blurred) == expected:
            best = ksize
    return best


def lowest_contrast_decodable(img, expected):
    best = None
    for factor in CONTRAST_LADDER:
        faded = cv2.addWeighted(
            img, factor, np.full_like(img, 128), 1 - factor, 0
        )
        if decode(faded) == expected:
            best = factor
    return best


def main():
    spec = json.loads(sys.argv[1])
    img = load(spec)
    value = decode(img)

    result = {"value": value}

    if spec.get("margin") and value:
        result["margin"] = {
            "smallest_px": smallest_decodable(img, value),
            "max_blur_kernel": blurriest_decodable(img, value),
            "min_contrast": lowest_contrast_decodable(img, value),
        }

    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001 - surfaced to Elixir as JSON
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
