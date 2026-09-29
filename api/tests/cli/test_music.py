import pytest
from click.testing import CliRunner

from funkwhale_api.cli import music


def _stalled_report():
    return {
        "transcoding_enabled": True,
        "prewarm_enabled": False,
        "older_than": 5,
        "long_transactions": [
            {
                "pid": 42,
                "state": "idle in transaction",
                "wait": "",
                "seconds": 90.0,
                "query": "INSERT INTO music_uploadversion",
            }
        ],
        "blocked": [
            {
                "blocked_pid": 7,
                "blocked_seconds": 12.0,
                "blocked_query": 'UPDATE "music_upload" SET "accessed_date"',
                "blocking_pid": 42,
                "blocking_state": "idle in transaction",
                "blocking_seconds": 90.0,
                "blocking_query": "INSERT INTO music_uploadversion",
            }
        ],
        "empty_versions": 0,
        "ladder_versions": 1,
        "finished_uploads": 3,
        "queues": {"transcode": 4, "celery": 0},
        "lock_error": None,
        "stalled": True,
    }


def test_transcode_status_rejects_both_switches():
    result = CliRunner().invoke(
        music.transcode_status, ["--disable-prewarm", "--enable-prewarm"]
    )
    assert result.exit_code != 0
    assert "only one" in result.output


def test_transcode_status_exit_3_when_stalled(mocker):
    mocker.patch.object(
        music, "collect_transcode_status", return_value=_stalled_report()
    )
    result = CliRunner().invoke(music.transcode_status, [])
    assert result.exit_code == 3
    assert "Playback lock check: STALLED" in result.output
    assert "pid 42" in result.output
    assert "pid 7" in result.output
    assert "transcode=4" in result.output


@pytest.mark.django_db
def test_transcode_status_disables_prewarm(preferences):
    preferences[music.PREWARM_PREF] = True
    result = CliRunner().invoke(music.transcode_status, ["--disable-prewarm"])
    assert result.exit_code == 0, result.output
    assert "Playback lock check: CLEAR" in result.output
    assert "changed from on to off" in result.output
    assert preferences[music.PREWARM_PREF] is False


@pytest.mark.django_db
def test_transcode_status_enable_is_idempotent(preferences):
    preferences[music.PREWARM_PREF] = True
    result = CliRunner().invoke(music.transcode_status, ["--enable-prewarm"])
    assert result.exit_code == 0, result.output
    assert "already on" in result.output
    assert preferences[music.PREWARM_PREF] is True


@pytest.mark.django_db
def test_collect_transcode_status_reads_postgres(preferences):
    preferences[music.PREWARM_PREF] = False
    report = music.collect_transcode_status(older_than=5)
    assert report["lock_error"] is None
    assert report["stalled"] is False
    assert report["prewarm_enabled"] is False
    assert "error" in report["queues"]
