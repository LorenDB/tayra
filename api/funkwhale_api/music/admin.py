from funkwhale_api.common import admin

from . import models


@admin.register(models.ArtistCredit)
class ArtistCreditAdmin(admin.ModelAdmin):
    list_display = [
        "artist",
        "credit",
        "joinphrase",
        "creation_date",
    ]
    search_fields = ["artist__name", "credit"]


@admin.register(models.Artist)
class ArtistAdmin(admin.ModelAdmin):
    list_display = ["name", "mbid", "creation_date", "modification_date"]
    search_fields = ["name", "mbid"]


@admin.register(models.Album)
class AlbumAdmin(admin.ModelAdmin):
    list_display = ["title", "mbid", "release_date", "creation_date"]
    search_fields = ["title", "mbid"]
    list_select_related = True

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "artist_credit":
            object_id = request.resolver_match.kwargs.get("object_id")
            kwargs["queryset"] = models.ArtistCredit.objects.filter(
                albums__id=object_id
            )

        return super().formfield_for_foreignkey(db_field, request, **kwargs)


@admin.register(models.Track)
class TrackAdmin(admin.ModelAdmin):
    list_display = ["title", "album", "mbid", "artist"]
    search_fields = ["title", "album__title", "mbid"]

    def artist(self, obj):
        return obj.get_artist_credit_string

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "artist_credit":
            object_id = request.resolver_match.kwargs.get("object_id")
            kwargs["queryset"] = models.ArtistCredit.objects.filter(
                tracks__id=object_id
            )
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


@admin.register(models.TrackActor)
class TrackActorAdmin(admin.ModelAdmin):
    list_display = ["user", "track", "upload", "internal"]
    search_fields = ["user__username", "track__title"]
    list_select_related = ["user", "track"]


@admin.register(models.ImportBatch)
class ImportBatchAdmin(admin.ModelAdmin):
    list_display = ["submitted_by", "creation_date", "import_request", "status"]
    list_select_related = ["submitted_by", "import_request"]
    list_filter = ["status"]
    search_fields = ["import_request__name", "source", "batch__pk", "mbid"]


@admin.register(models.ImportJob)
class ImportJobAdmin(admin.ModelAdmin):
    list_display = ["source", "batch", "upload", "status", "mbid"]
    list_select_related = ["upload", "batch"]
    search_fields = ["source", "batch__pk", "mbid"]
    list_filter = ["status"]


@admin.register(models.Upload)
class UploadAdmin(admin.ModelAdmin):
    list_display = [
        "track",
        "audio_file",
        "source",
        "duration",
        "mimetype",
        "size",
        "bitrate",
        "import_status",
        "library",
    ]
    list_select_related = ["track"]
    search_fields = [
        "source",
        "acoustid_track_id",
        "track__title",
        "track__album__title",
        "track__artist_credit__artist__name",
    ]
    list_filter = ["mimetype", "import_status", "library__privacy_level"]


@admin.register(models.UploadVersion)
class UploadVersionAdmin(admin.ModelAdmin):
    list_display = [
        "upload",
        "audio_file",
        "mimetype",
        "size",
        "bitrate",
        "creation_date",
        "accessed_date",
    ]
    list_select_related = ["upload"]
    search_fields = [
        "upload__source",
        "upload__acoustid_track_id",
        "upload__track__title",
        "upload__track__album__title",
        "upload__track__artist_credit__artist__name",
    ]
    list_filter = ["mimetype"]


def launch_scan(modeladmin, request, queryset):
    for library in queryset:
        library.schedule_scan(user=request.user, force=True)


launch_scan.short_description = "Launch scan"


@admin.register(models.Library)
class LibraryAdmin(admin.ModelAdmin):
    list_display = ["id", "name", "owner", "uuid", "privacy_level", "creation_date"]
    list_select_related = True
    search_fields = ["uuid", "name", "owner__username"]
    list_filter = ["privacy_level"]
    actions = [launch_scan]


@admin.register(models.LibraryScan)
class LibraryScanAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "library",
        "submitted_by",
        "status",
        "creation_date",
        "modification_date",
        "status",
        "total_files",
        "processed_files",
        "errored_files",
    ]
    list_select_related = True
    search_fields = ["submitted_by__username", "library__name"]
    list_filter = ["status"]
