"""Server-side checks for transcoding locks and the prewarm switch."""

import click
from django.db import connection

from funkwhale_api.common import preferences
from funkwhale_api.music import models
from funkwhale_api.music.quality import ladder_bitrate_set

from . import base

PREWARM_PREF = "music__auto_prewarm_qualities"
TRANSCODING_PREF = "music__transcoding_enabled"


@base.cli.group()
def music():
    """Inspect and control audio transcoding"""
    pass


def _one_line(value, limit=240):
    return " ".join(str(value or "").split())[:limit]


def _queue_depths():
    """Return Redis list lengths for the Celery queues, or an error string."""
    from django.conf import settings

    url = getattr(settings, "CELERY_BROKER_URL", "") or ""
    scheme = url.split("://", 1)[0] if "://" in url else ""
    if scheme not in ("redis", "rediss", "unix"):
        return {"error": f"broker is {scheme or 'unset'}, not Redis"}
    try:
        import redis

        client = redis.Redis.from_url(
            url, socket_connect_timeout=0.3, socket_timeout=0.3
        )
        return {
            "transcode": int(client.llen("transcode")),
            "celery": int(client.llen("celery")),
        }
    except Exception as exc:
        return {"error": _one_line(exc, 180)}


def collect_transcode_status(older_than=5):
    """Snapshot preferences, queue depth, and Postgres lock waits.

    A stalled report means some database transaction has been open longer
    than ``older_than`` seconds, or a query is waiting on another session's
    lock. That is the failure mode where playback spins until the encode
    holding the upload row finishes.
    """
    older_than = max(int(older_than), 1)
    report = {
        "transcoding_enabled": bool(preferences.get(TRANSCODING_PREF)),
        "prewarm_enabled": bool(preferences.get(PREWARM_PREF)),
        "older_than": older_than,
        "long_transactions": [],
        "blocked": [],
        "empty_versions": models.UploadVersion.objects.filter(size=0).count(),
        "ladder_versions": models.UploadVersion.objects.filter(
            size__gt=0,
            mimetype="audio/mpeg",
            bitrate__in=ladder_bitrate_set(),
        ).count(),
        "finished_uploads": models.Upload.objects.filter(
            import_status__in=["finished", "skipped"]
        ).count(),
        "queues": _queue_depths(),
        "lock_error": None,
    }

    if connection.vendor != "postgresql":
        report["lock_error"] = f"lock check needs PostgreSQL (got {connection.vendor})"
        report["stalled"] = False
        return report

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT pid,
                       state,
                       COALESCE(wait_event_type, ''),
                       COALESCE(wait_event, ''),
                       EXTRACT(EPOCH FROM (clock_timestamp() - xact_start)),
                       LEFT(query, 240)
                FROM pg_stat_activity
                WHERE datname = current_database()
                  AND pid <> pg_backend_pid()
                  AND xact_start IS NOT NULL
                  AND clock_timestamp() - xact_start
                      > make_interval(secs => %s)
                ORDER BY xact_start
                LIMIT 20
                """,
                [older_than],
            )
            for pid, state, wait_type, wait_event, seconds, query in cursor.fetchall():
                wait = " / ".join(part for part in (wait_type, wait_event) if part)
                report["long_transactions"].append(
                    {
                        "pid": pid,
                        "state": state,
                        "wait": wait,
                        "seconds": float(seconds or 0),
                        "query": _one_line(query),
                    }
                )

            cursor.execute(
                """
                SELECT blocked.pid,
                       EXTRACT(EPOCH FROM (clock_timestamp() - blocked.query_start)),
                       LEFT(blocked.query, 240),
                       blocking.pid,
                       blocking.state,
                       EXTRACT(EPOCH FROM (clock_timestamp() - blocking.xact_start)),
                       LEFT(blocking.query, 240)
                FROM pg_stat_activity blocked
                JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS b(pid)
                    ON TRUE
                JOIN pg_stat_activity blocking ON blocking.pid = b.pid
                WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0
                LIMIT 20
                """
            )
            for row in cursor.fetchall():
                report["blocked"].append(
                    {
                        "blocked_pid": row[0],
                        "blocked_seconds": float(row[1] or 0),
                        "blocked_query": _one_line(row[2]),
                        "blocking_pid": row[3],
                        "blocking_state": row[4],
                        "blocking_seconds": float(row[5] or 0),
                        "blocking_query": _one_line(row[6]),
                    }
                )
    except Exception as exc:
        report["lock_error"] = _one_line(exc, 300)

    report["stalled"] = bool(report["long_transactions"] or report["blocked"])
    return report


def format_transcode_status(report, change_note=None):
    lines = []
    checked = not report.get("lock_error")
    if report.get("lock_error") and not report["stalled"]:
        lines.append(f"Playback lock check: UNKNOWN ({report['lock_error']})")
    elif report["stalled"]:
        lines.append(
            "Playback lock check: STALLED "
            f"({len(report['long_transactions'])} long transaction(s), "
            f"{len(report['blocked'])} query(ies) waiting on a lock)"
        )
    else:
        lines.append("Playback lock check: CLEAR")

    if change_note:
        lines.append(change_note)

    prewarm = "on" if report["prewarm_enabled"] else "off"
    transcoding = "on" if report["transcoding_enabled"] else "off"
    lines.append(f"Background prewarm ({PREWARM_PREF}): {prewarm}")
    lines.append(f"Transcoding enabled ({TRANSCODING_PREF}): {transcoding}")
    lines.append(
        "Same switch in the app: Instance settings, Music, "
        '"Background multi-quality transcoding".'
    )
    lines.append("  funkwhale-manage fw music transcode-status --disable-prewarm")
    lines.append("  funkwhale-manage fw music transcode-status --enable-prewarm")
    lines.append(
        "Disabling prewarm does not stop ffmpeg that is already running. "
        "Restart the worker after turning it off:"
    )
    lines.append("  docker compose restart celeryworker")

    queues = report.get("queues") or {}
    if "transcode" in queues:
        lines.append(
            f"Celery queue depth: transcode={queues['transcode']} "
            f"celery={queues['celery']}"
        )
    else:
        lines.append(
            f"Celery queue depth: unavailable ({queues.get('error', 'unknown')})"
        )

    lines.append(
        f"Finished uploads: {report['finished_uploads']}; "
        f"ready ladder files: {report['ladder_versions']}; "
        f"empty derivative rows (size 0): {report['empty_versions']}"
    )
    if report["empty_versions"]:
        lines.append(
            "Size-0 rows are leftovers from encodes that inserted a database "
            "row before ffmpeg finished. They are not served."
        )

    older = report["older_than"]
    if not checked and not report["long_transactions"] and not report["blocked"]:
        lines.append(
            "Lock tables were not read, so this run cannot say playback is clear."
        )
    else:
        if report["long_transactions"]:
            lines.append(f"Transactions open longer than {older}s:")
            for item in report["long_transactions"]:
                wait = f" waiting on {item['wait']}" if item["wait"] else ""
                lines.append(
                    f"  pid {item['pid']} {item['state']} "
                    f"{item['seconds']:.1f}s{wait}: {item['query']}"
                )
        else:
            lines.append(f"No other transaction has been open longer than {older}s.")

        if report["blocked"]:
            lines.append("Queries waiting on a lock:")
            for item in report["blocked"]:
                lines.append(
                    f"  pid {item['blocked_pid']} blocked "
                    f"{item['blocked_seconds']:.1f}s: {item['blocked_query']}"
                )
                lines.append(
                    f"    blocked by pid {item['blocking_pid']} "
                    f"({item['blocking_state']}, open {item['blocking_seconds']:.1f}s): "
                    f"{item['blocking_query']}"
                )
        else:
            lines.append("No queries are waiting on a lock.")

    if report["stalled"]:
        lines.append(
            "A listen cannot proceed while it waits on one of these "
            "transactions. Restarting celeryworker rolls the encode back and "
            "releases the lock."
        )
    return "\n".join(lines)


def set_prewarm(enabled):
    """Set the background prewarm preference. Returns a one-line change note."""
    current = bool(preferences.get(PREWARM_PREF))
    if current == enabled:
        state = "on" if enabled else "off"
        return f"Background prewarm already {state}."
    preferences.set(PREWARM_PREF, enabled)
    before = "on" if current else "off"
    after = "on" if enabled else "off"
    return f"Background prewarm changed from {before} to {after}."


@music.command("transcode-status")
@click.option(
    "--disable-prewarm",
    is_flag=True,
    help="Turn off background multi-quality transcoding (music__auto_prewarm_qualities).",
)
@click.option(
    "--enable-prewarm",
    is_flag=True,
    help="Turn background multi-quality transcoding back on.",
)
@click.option(
    "--older-than",
    default=5,
    show_default=True,
    type=int,
    help="Report transactions open longer than this many seconds.",
)
@click.pass_context
def transcode_status(ctx, disable_prewarm, enable_prewarm, older_than):
    """Show whether transcoding is blocking playback, and toggle background prewarm.

    Exits 3 when a long transaction or a lock wait is in progress.
    """
    if disable_prewarm and enable_prewarm:
        raise click.UsageError(
            "Pass only one of --disable-prewarm or --enable-prewarm."
        )

    change_note = None
    if disable_prewarm:
        change_note = set_prewarm(False)
    elif enable_prewarm:
        change_note = set_prewarm(True)

    report = collect_transcode_status(older_than=older_than)
    click.echo(format_transcode_status(report, change_note=change_note))
    if report["stalled"]:
        ctx.exit(3)
