"""Bulk listening import with enrich-or-create matching.

See docs/specs/rich-client-data/index.md § Bulk import.
"""

from __future__ import annotations

import datetime
from collections import defaultdict

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone

from funkwhale_api.client_data.models import ClientDevice
from funkwhale_api.music.models import Track

from . import models

BULK_MAX_ITEMS = 500
DEFAULT_DEDUP_WINDOW_SECONDS = 2


def process_bulk_listenings(user, *, mode, items, dedup_window_seconds):
    """
    Apply a batch of listening import items for ``user``.

    ``items`` is a list of validated dicts with keys:
      track (int), creation_date (datetime), duration_seconds (int|None),
      source_device (UUID|None), client_session_id (UUID|None)

    Returns::

        {
            "created": int,
            "enriched": int,
            "skipped_duplicate": int,
            "errors": [{"index": int, "code": str, "detail": str}, ...],
        }

    Never triggers plugins or activity.
    """
    result = {
        "created": 0,
        "enriched": 0,
        "skipped_duplicate": 0,
        "errors": [],
    }
    if not items:
        return result

    now = timezone.now()
    window = datetime.timedelta(seconds=dedup_window_seconds)

    track_ids = {item["track"] for item in items}
    device_uuids = {
        item["source_device"]
        for item in items
        if item.get("source_device") is not None
    }

    existing_track_ids = set(
        Track.objects.filter(pk__in=track_ids).values_list("pk", flat=True)
    )
    devices_by_uuid = {
        d.uuid: d
        for d in ClientDevice.objects.filter(user=user, uuid__in=device_uuids)
    }

    # Validate rows; keep (index, resolved item dict) for matching.
    valid = []
    for index, item in enumerate(items):
        if item["track"] not in existing_track_ids:
            result["errors"].append(
                {
                    "index": index,
                    "code": "track_not_found",
                    "detail": f"Track {item['track']} does not exist",
                }
            )
            continue

        device = None
        device_uuid = item.get("source_device")
        if device_uuid is not None:
            device = devices_by_uuid.get(device_uuid)
            if device is None:
                result["errors"].append(
                    {
                        "index": index,
                        "code": "device_not_registered",
                        "detail": "Register the device via POST /api/v1/client-devices/",
                    }
                )
                continue
            if not device.is_active:
                result["errors"].append(
                    {
                        "index": index,
                        "code": "device_inactive",
                        "detail": (
                            "Device is inactive; re-register via "
                            "POST /api/v1/client-devices/"
                        ),
                    }
                )
                continue

        # creation_date is required on the serializer; still guard for callers.
        creation_date = item.get("creation_date")
        if creation_date is None:
            result["errors"].append(
                {
                    "index": index,
                    "code": "creation_date_required",
                    "detail": "creation_date is required for bulk import",
                }
            )
            continue

        valid.append(
            {
                "index": index,
                "track_id": item["track"],
                "creation_date": creation_date,
                "duration_seconds": item.get("duration_seconds"),
                "device": device,
                "client_session_id": item.get("client_session_id"),
            }
        )

    if not valid:
        return result

    dates = [v["creation_date"] for v in valid]
    t_min = min(dates) - window
    t_max = max(dates) + window
    valid_track_ids = {v["track_id"] for v in valid}
    session_ids = [
        v["client_session_id"] for v in valid if v["client_session_id"] is not None
    ]

    date_q = Q(
        creation_date__range=(t_min, t_max),
        track_id__in=valid_track_ids,
    )
    if session_ids:
        candidate_q = date_q | Q(client_session_id__in=session_ids)
    else:
        candidate_q = date_q

    # Prefer matching other rich rows only — never window-merge onto stock thin
    # scrobbles (those stay ignored by stats/list). Session-id matches still
    # resolve via the session index even if somehow thin.
    candidates = list(
        models.Listening.objects.filter(user=user)
        .filter(candidate_q)
        .only(
            "id",
            "track_id",
            "creation_date",
            "duration_seconds",
            "source_device_id",
            "client_session_id",
            "updated_at",
        )
    )

    by_session = {
        c.client_session_id: c for c in candidates if c.client_session_id is not None
    }
    by_track = defaultdict(list)
    for c in candidates:
        # Window matching: only consider already-rich rows so import creates
        # new rich listens next to legacy stock scrobbles instead of mutating them.
        if c.is_rich:
            by_track[c.track_id].append(c)

    to_create = []
    # Existing-row enrich intents: (pk, row_dict). Applied under select_for_update.
    enrich_intents = []

    for row in valid:
        match = _find_match(
            row,
            by_session=by_session,
            by_track=by_track,
            dedup_window_seconds=dedup_window_seconds,
        )

        if match is not None:
            if mode == "create_only":
                result["skipped_duplicate"] += 1
                continue

            # Pending create from earlier in this batch: mutate in place.
            if match.pk is None:
                changed = _apply_enrich(match, row)
                if changed:
                    result["enriched"] += 1
                else:
                    result["skipped_duplicate"] += 1
                continue

            # Existing DB row: decide using prefetched values for counters, then
            # re-apply under lock at write time.
            if _would_enrich(match, row):
                result["enriched"] += 1
                enrich_intents.append((match.pk, row))
            else:
                result["skipped_duplicate"] += 1
            continue

        # bulk_create does not run auto_now; set updated_at explicitly (Django 3.2).
        listening = models.Listening(
            user=user,
            track_id=row["track_id"],
            creation_date=row["creation_date"],
            duration_seconds=row["duration_seconds"],
            source_device=row["device"],
            client_session_id=row["client_session_id"],
            updated_at=now,
        )
        to_create.append(listening)
        result["created"] += 1

        # Make subsequent items in this batch see the pending create.
        if listening.client_session_id is not None:
            by_session[listening.client_session_id] = listening
        by_track[listening.track_id].append(listening)

    if not to_create and not enrich_intents:
        return result

    with transaction.atomic():
        if enrich_intents:
            pks = {pk for pk, _ in enrich_intents}
            locked = {
                obj.pk: obj
                for obj in models.Listening.objects.select_for_update()
                .filter(user=user, pk__in=pks)
                .only(
                    "id",
                    "duration_seconds",
                    "source_device_id",
                    "updated_at",
                    "client_session_id",
                    "track_id",
                    "creation_date",
                )
            }
            to_update = []
            seen_pks = set()
            for pk, row in enrich_intents:
                fresh = locked.get(pk)
                if fresh is None:
                    continue
                if _apply_enrich(fresh, row):
                    fresh.updated_at = now
                    if pk not in seen_pks:
                        to_update.append(fresh)
                        seen_pks.add(pk)
            if to_update:
                models.Listening.objects.bulk_update(
                    to_update,
                    ["duration_seconds", "source_device", "updated_at"],
                )

        if to_create:
            _bulk_create_with_conflict_recovery(user, to_create, result, now)

    return result


def _bulk_create_with_conflict_recovery(user, to_create, result, now):
    """
    bulk_create, falling back to per-row insert on unique session races.

    Concurrent bulk/single-create for the same client_session_id must not 500
    the whole batch. On conflict, merge (enrich) or skip and adjust counters.
    """
    try:
        with transaction.atomic():
            models.Listening.objects.bulk_create(to_create)
        return
    except IntegrityError:
        pass

    for listening in to_create:
        try:
            with transaction.atomic():
                models.Listening.objects.bulk_create([listening])
        except IntegrityError:
            if not listening.client_session_id:
                raise
            try:
                existing = (
                    models.Listening.objects.select_for_update()
                    .filter(user=user, client_session_id=listening.client_session_id)
                    .get()
                )
            except models.Listening.DoesNotExist:
                raise

            row = {
                "duration_seconds": listening.duration_seconds,
                "device": listening.source_device,
            }
            result["created"] -= 1
            if _apply_enrich(existing, row):
                existing.updated_at = now
                existing.save(
                    update_fields=["duration_seconds", "source_device", "updated_at"]
                )
                result["enriched"] += 1
            else:
                result["skipped_duplicate"] += 1


def _find_match(row, *, by_session, by_track, dedup_window_seconds):
    """Session-id match wins; else closest window match with tie-breaks."""
    session_id = row["client_session_id"]
    if session_id is not None and session_id in by_session:
        return by_session[session_id]

    creation = row["creation_date"]
    track_candidates = by_track.get(row["track_id"], [])
    within = []
    for candidate in track_candidates:
        if candidate.creation_date is None:
            continue
        delta = abs((candidate.creation_date - creation).total_seconds())
        if delta <= dedup_window_seconds:
            within.append((delta, candidate))

    if not within:
        return None

    # Tie-break: min |Δ|, then duration_seconds IS NULL, then lowest id.
    def sort_key(pair):
        delta, candidate = pair
        null_duration = 0 if candidate.duration_seconds is None else 1
        # Pending creates have no id yet; rank after real rows with same delta.
        cid = candidate.pk if candidate.pk is not None else float("inf")
        return (delta, null_duration, cid)

    within.sort(key=sort_key)
    return within[0][1]


def _would_enrich(match, row):
    """Return True if enrich would change any field (read-only check)."""
    incoming_dur = row.get("duration_seconds")
    if incoming_dur is not None:
        existing = match.duration_seconds
        if existing is None or incoming_dur > existing:
            return True

    device = row.get("device")
    if device is not None and match.source_device_id != device.pk:
        return True
    return False


def _apply_enrich(match, row):
    """
    Mutate ``match`` with enrich rules. Returns True if any field changed.

    Never decreases duration_seconds. Null → non-null duration counts as change.
    source_device updates when incoming device differs from current.
    """
    changed = False

    incoming_dur = row.get("duration_seconds")
    if incoming_dur is not None:
        existing = match.duration_seconds
        if existing is None:
            match.duration_seconds = incoming_dur
            changed = True
        elif incoming_dur > existing:
            match.duration_seconds = incoming_dur
            changed = True

    device = row.get("device")
    if device is not None and match.source_device_id != device.pk:
        match.source_device = device
        match.source_device_id = device.pk
        changed = True

    return changed
