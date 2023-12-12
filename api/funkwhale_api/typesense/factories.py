from troi import Artist, Element, Playlist, Recording
from troi.patch import Patch

recording_list = [
    Recording(
        name="I Want It That Way",
        mbid="87dfa566-21c3-45ed-bc42-1d345b8563fa",
        artist=Artist(name="artist_name"),
    ),
    Recording(name="Untouchable", artist=Artist(name="Another lol")),
    Recording(
        name="The Perfect Kiss",
        mbid="ec0da94e-fbfe-4eb0-968e-024d4c32d1d0",
        artist=Artist(name="artist_name2"),
    ),
    Recording(
        name="Love Your Voice",
        mbid="93726547-f8c0-4efd-8e16-d2dee76500f6",
        artist=Artist(name="artist_name"),
    ),
    Recording(
        name="Hall of Fame",
        mbid="395bd5a1-79cc-4e04-8869-ca9eabc78d09",
        artist=Artist(name="artist_name_3"),
    ),
]


class DummyElement(Element):
    """Dummy element that returns a fixed playlist for testing"""

    @staticmethod
    def outputs():
        return [Playlist]

    def read(self, sources):
        recordings = recording_list

        return [
            Playlist(
                name="Test Export Playlist",
                description="A playlist to test exporting playlists to spotify",
                recordings=recordings,
            )
        ]


class DummyPatch(Patch):
    """Dummy patch that always returns a fixed set of recordings for testing"""

    @staticmethod
    def slug():
        return "test-patch"

    def create(self, inputs):
        return DummyElement()

    @staticmethod
    def outputs():
        return [Recording]


recommended_recording_mbids = [
    "87dfa566-21c3-45ed-bc42-1d345b8563fa",
    "ec0da94e-fbfe-4eb0-968e-024d4c32d1d0",
    "93726547-f8c0-4efd-8e16-d2dee76500f6",
    "395bd5a1-79cc-4e04-8869-ca9eabc78d09",
]

typesense_search_result = {
    "facet_counts": [],
    "found": 1,
    "out_of": 1,
    "page": 1,
    "request_params": {
        "collection_name": "canonical_fw_data",
        "per_page": 10,
        "q": "artist_nameiwantitthatway",
    },
    "search_time_ms": 1,
    "hits": [
        {
            "highlights": [
                {
                    "field": "combined",
                    "snippet": "string",
                    "matched_tokens": ["string"],
                }
            ],
            "document": {
                "pk": "1",
                "combined": "artist_nameiwantitthatway",
            },
            "text_match": 130916,
        },
        {
            "highlights": [
                {
                    "field": "combined",
                    "snippet": "string",
                    "matched_tokens": ["string"],
                }
            ],
            "document": {
                "pk": "2",
                "combined": "artist_nameiwantitthatway",
            },
            "text_match": 130916,
        },
    ],
}
