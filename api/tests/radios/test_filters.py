from funkwhale_api.radios import filters


def test_clean_config_artist_name_sorting(factories):
    artist3 = factories["music.Artist"](name="The Green Eyes")
    artist2 = factories["music.Artist"](name="The Green Eyed Machine")
    artist1 = factories["music.Artist"](name="The Green Seed")
    factories["music.Artist"]()
    filter_config = {"type": "artist", "ids": [artist3.pk, artist1.pk, artist2.pk]}
    artist_filter = filters.ArtistFilter()
    config = artist_filter.clean_config(filter_config)
    # list of names whose artists have been sorted by name then by id
    sorted_names = [
        a.name
        for a in list(
            sorted([artist2, artist1, artist3], key=lambda x: (len(x.name), x.id))
        )
    ]
    assert config["names"] == sorted_names


def test_clean_config_tag_name_sorting(factories):
    tag3 = factories["tags.Tag"](name="Rock")
    tag2 = factories["tags.Tag"](name="Classic")
    tag1 = factories["tags.Tag"](name="Punk")
    factories["tags.Tag"]()
    filter_config = {"type": "tag", "names": [tag3.name, tag1.name, tag2.name]}
    tag_filter = filters.TagFilter()
    config = tag_filter.clean_config(filter_config)
    # list of names whose tags have been sorted by name then by id
    sorted_names = [
        a.name
        for a in list(sorted([tag2, tag1, tag3], key=lambda x: (len(x.name), x.id)))
    ]
    assert config["names"] == sorted_names
