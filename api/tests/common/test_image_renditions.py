from PIL import Image

from funkwhale_api.common.image_renditions import (
    SafeCroppedImage,
    install_safe_image_sizers,
    normalize_rendition_image,
)


def _red_palette_image():
    image = Image.new("P", (24, 24))
    palette = [0, 0, 0, 220, 12, 18] + [0] * (768 - 6)
    image.putpalette(palette)
    image.paste(1, (0, 0, 24, 24))
    return image


def test_normalize_keeps_palette_color_and_drops_icc():
    image = _red_palette_image()
    image.info["icc_profile"] = b"not-a-real-profile"
    cleaned, save_kwargs = normalize_rendition_image(
        image,
        "JPEG",
        {"format": "JPEG", "quality": 95, "icc_profile": b"not-a-real-profile"},
    )

    assert cleaned.mode == "RGB"
    pixel = cleaned.getpixel((1, 1))
    assert pixel[0] > 180
    assert pixel[1] < 40
    assert pixel[2] < 40
    assert "icc_profile" not in save_kwargs
    assert save_kwargs["progressive"] is False
    assert save_kwargs["subsampling"] == 2


def test_normalize_converts_cmyk_without_keeping_profile():
    image = Image.new("CMYK", (8, 8), (0, 200, 200, 0))
    # A gray-looking result comes from re-attaching this blob, not from RGB.
    image.info["icc_profile"] = b"profile"
    cleaned, save_kwargs = normalize_rendition_image(
        image, "JPEG", {"format": "JPEG", "icc_profile": b"profile", "quality": 90}
    )
    assert cleaned.mode == "RGB"
    assert "icc_profile" not in save_kwargs


def test_safe_crop_preprocess_uses_normalize():
    install_safe_image_sizers()
    sizer = SafeCroppedImage(
        path_to_image="covers/art.png",
        storage=None,
        create_on_demand=False,
        ppoi=(0.5, 0.5),
    )
    image = _red_palette_image()
    cleaned, save_kwargs = sizer.preprocess(image, "PNG")
    assert cleaned.mode == "RGB"
    assert "icc_profile" not in save_kwargs
    pixel = cleaned.getpixel((0, 0))
    assert pixel[0] > 180


def test_crop_sizer_is_replaced():
    from versatileimagefield.registry import versatileimagefield_registry

    install_safe_image_sizers()
    assert versatileimagefield_registry._sizedimage_registry["crop"] is SafeCroppedImage
