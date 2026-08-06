import xml.etree.ElementTree as ET

from rest_framework import negotiation, renderers


# from https://stackoverflow.com/a/8915039
# because I want to avoid a lxml dependency just for outputting cdata properly
# in a RSS feed
def CDATA(text=None):
    element = ET.Element("![CDATA[")
    element.text = text
    return element


ET._original_serialize_xml = ET._serialize_xml


def _serialize_xml(write, elem, qnames, namespaces, **kwargs):
    if elem.tag == "![CDATA[":
        write(f"<{elem.tag}{elem.text}]]>")
        return
    return ET._original_serialize_xml(write, elem, qnames, namespaces, **kwargs)


ET._serialize_xml = ET._serialize["xml"] = _serialize_xml
# end of tweaks


def dict_to_xml_tree(root_tag, d, parent=None):
    root = ET.Element(root_tag)
    for key, value in d.items():
        if isinstance(value, dict):
            root.append(dict_to_xml_tree(key, value, parent=root))
        elif isinstance(value, list):
            for obj in value:
                if isinstance(obj, dict):
                    el = dict_to_xml_tree(key, obj, parent=root)
                else:
                    el = ET.Element(key)
                    el.text = str(obj)
                root.append(el)
        else:
            if key == "value":
                root.text = str(value)
            elif key == "cdata_value":
                root.append(CDATA(value))
            else:
                root.set(key, str(value))
    return root


class PodcastRSSRenderer(renderers.JSONRenderer):
    media_type = "application/rss+xml"

    def render(self, data, accepted_media_type=None, renderer_context=None):
        if not data:
            # when stream view is called, we don't have any data
            return super().render(data, accepted_media_type, renderer_context)
        final = {
            "version": "2.0",
            "xmlns:atom": "http://www.w3.org/2005/Atom",
            "xmlns:itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd",
            "xmlns:content": "http://purl.org/rss/1.0/modules/content/",
            "xmlns:media": "http://search.yahoo.com/mrss/",
        }
        final.update(data)
        tree = dict_to_xml_tree("rss", final)
        return render_xml(tree)


class PodcastRSSContentNegociation(negotiation.DefaultContentNegotiation):
    def select_renderer(self, request, renderers, format_suffix=None):
        return (PodcastRSSRenderer(), PodcastRSSRenderer.media_type)


def render_xml(tree):
    return b'<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(
        tree, encoding="utf-8"
    )
