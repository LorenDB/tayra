"""Cover renditions that stay colorful in Flutter and browser decoders.

django-versatileimagefield copies the source ICC profile onto the resized
file even after converting the pixels (palette, CMYK, or alpha flattened to
RGB). Decoders that honor that profile — Skia in the Flutter client, and
Chrome — then paint the crop mostly gray. Palette-mode sources are also
resized as indexes unless they are converted first, which muddies the color.

Crops keep the stock filename key, so existing URLs do not change. Files
already written with a bad profile stay on disk until thumbnails are
regenerated.
"""

import io
import logging

from PIL import Image, ImageOps
from versatileimagefield.registry import versatileimagefield_registry
from versatileimagefield.versatileimagefield import CroppedImage

logger = logging.getLogger(__name__)

# libjpeg 4:2:0. Explicit so quality=95 cannot switch to 4:4:4, which the
# Flutter JPEG scaler decodes without chroma.
_JPEG_SUBSAMPLING_420 = 2


def _flatten_for_format(image, fmt):
    """Return an image whose mode matches what the encoder will write."""
    fmt = (fmt or "").upper()
    if image.mode == "P":
        image = image.convert("RGBA" if "transparency" in image.info else "RGB")
    elif image.mode == "PA":
        image = image.convert("RGBA")
    elif image.mode == "LA":
        image = image.convert("RGBA")
    elif image.mode not in ("RGB", "RGBA", "L"):
        image = image.convert("RGB")

    if fmt in ("JPEG", "JPG") and image.mode not in ("RGB", "L"):
        if image.mode in ("RGBA", "LA"):
            background = Image.new("RGB", image.size, (255, 255, 255))
            rgba = image.convert("RGBA")
            background.paste(rgba, mask=rgba.split()[-1])
            return background
        return image.convert("RGB")
    if fmt == "WEBP" and image.mode not in ("RGB", "RGBA", "L"):
        return image.convert("RGBA")
    if fmt == "PNG" and image.mode == "P":
        return image.convert("RGBA")
    return image


def normalize_rendition_image(image, image_format, save_kwargs):
    """Drop foreign color profiles and encode JPEGs the client can scale."""
    fmt = (image_format or save_kwargs.get("format") or "").upper()
    image = _flatten_for_format(image, fmt)
    save_kwargs = dict(save_kwargs)
    # Pixels are now sRGB-ish raw values. Re-attaching the source profile
    # is what paints the crop gray.
    save_kwargs.pop("icc_profile", None)
    if fmt in ("JPEG", "JPG"):
        save_kwargs["format"] = "JPEG"
        save_kwargs["progressive"] = False
        # Grayscale JPEGs have one component; forcing 4:2:0 indexes past it.
        if image.mode == "RGB":
            save_kwargs["subsampling"] = _JPEG_SUBSAMPLING_420
    elif fmt:
        save_kwargs["format"] = fmt
    return image, save_kwargs


class SafeCroppedImage(CroppedImage):
    """Crop sizer that normalizes pixels before resizing."""

    def preprocess(self, image, image_format):
        image, save_kwargs = super().preprocess(image, image_format)
        try:
            return normalize_rendition_image(image, image_format, save_kwargs)
        except Exception:
            logger.exception("Cover rendition normalize failed; using stock crop")
            save_kwargs.pop("icc_profile", None)
            return image, save_kwargs


def encode_cover_upload(image, fmt):
    """Re-encode an upload without EXIF or a foreign ICC profile.

    Orientation is baked into the pixels first. JPEGs are baseline 4:2:0 so
    the Flutter client can scale them without dropping chroma.
    """
    oriented = ImageOps.exif_transpose(image)
    if oriented is not None:
        image = oriented
    image = _flatten_for_format(image, fmt)
    save_kwargs = {"format": fmt}
    upper = (fmt or "").upper()
    if upper in ("JPEG", "JPG", "WEBP"):
        save_kwargs["quality"] = 95
    if upper in ("JPEG", "JPG"):
        save_kwargs["exif"] = b""
        if image.mode == "RGB":
            save_kwargs["subsampling"] = _JPEG_SUBSAMPLING_420
    output = io.BytesIO()
    image.save(output, **save_kwargs)
    return output.getvalue()


def install_safe_image_sizers():
    """Replace the stock crop sizer. Safe to call more than once."""
    # The versatileimagefield import above registers the built-in sizers.
    current = versatileimagefield_registry._sizedimage_registry.get("crop")
    if current is SafeCroppedImage:
        return
    if current is not None:
        versatileimagefield_registry.unregister_sizer("crop")
    versatileimagefield_registry.register_sizer("crop", SafeCroppedImage)
