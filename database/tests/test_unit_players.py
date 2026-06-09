# tests/test_unit_players.py
#
# UNIT TESTS — Player creation & retrieval (Category 1 + 2)
#
# "Unit" înseamnă că fiecare test verifică un singur comportament izolat.
# pytest descoperă automat orice funcție care începe cu „test_".
#
# Rulare locală:
#   pip install pytest
#   pytest tests/ -v
#
# Rulare în GitHub Actions: automat la fiecare push/PR (vezi .github/workflows/tests.yml)

import time
import math
import pytest
from models import BattleRecord, Player, PlayerStats
from database_manager import DatabaseManager
from player_repository import PlayerRepository
from player_stats_repository import PlayerStatsRepository


# ─────────────────────────────────────────────────────────────
# Fixture — baza de date de test (in-memory, izolată per test)
#
# @pytest.fixture = funcție care pregătește resurse pentru teste.
# „scope='function'" (default) înseamnă că se resetează COMPLET
# înainte de fiecare funcție de test — niciun test nu afectează altul.
# ─────────────────────────────────────────────────────────────

@pytest.fixture
def db():
    """Creează o bază de date in-memory SQLite fresh pentru fiecare test."""
    manager = DatabaseManager(":memory:")
    manager.initialize()
    yield manager                  # <- testul rulează aici
    manager.close()                # <- cleanup automat după test


@pytest.fixture
def player_repo(db):
    """Fixture care depinde de 'db' — pytest injectează automat dependința."""
    return PlayerRepository(db)


@pytest.fixture
def stats_repo(db):
    return PlayerStatsRepository(db)


def _uid(base: str) -> str:
    """Generează un nume unic pentru a evita coliziuni între teste."""
    return f"Test_{base}_{int(time.time() * 1_000_000)}"


# ─────────────────────────────────────────────────────────────
# UNIT TEST 1 — Creare player valid
# ─────────────────────────────────────────────────────────────

def test_create_player_returns_player_object(player_repo):
    """Un player valid trebuie să returneze un obiect Player, nu None."""
    player = player_repo.create_player(_uid("Valid"))
    assert player is not None


def test_create_player_assigns_positive_id(player_repo):
    """ID-ul asignat trebuie să fie un întreg pozitiv (auto-increment din DB)."""
    player = player_repo.create_player(_uid("ID"))
    assert player is not None
    assert player.player_id > 0


def test_create_player_autocreates_stats_row(player_repo, stats_repo):
    """La creare, trebuie generat automat un rând în tabela PlayerStats."""
    player = player_repo.create_player(_uid("AutoStats"))
    assert player is not None

    stats = stats_repo.get_player_stats(player.player_id)
    assert stats is not None
    assert stats.total_battles == 0    # jucătorul nou nu a jucat nimic


def test_new_player_starts_with_elo_zero(player_repo):
    """ELO inițial trebuie să fie 0 (niciun meci jucat)."""
    player = player_repo.create_player(_uid("ELO"))
    assert player is not None

    fresh = player_repo.get_player_by_id(player.player_id)
    assert fresh is not None
    assert fresh.elo == 0


# ─────────────────────────────────────────────────────────────
# UNIT TEST 2 — Validare input la creare
# ─────────────────────────────────────────────────────────────

def test_create_player_rejects_empty_name(player_repo):
    """Numele gol '' trebuie respins — returnează None."""
    result = player_repo.create_player("")
    assert result is None


def test_create_player_rejects_whitespace_name(player_repo):
    """Numele format doar din spații trebuie respins."""
    result = player_repo.create_player("   ")
    assert result is None


def test_create_player_rejects_duplicate_name(player_repo):
    """Al doilea player cu același nume trebuie să returneze None."""
    name = _uid("Dup")
    player_repo.create_player(name)          # primul — ok
    duplicate = player_repo.create_player(name)  # al doilea — trebuie respins
    assert duplicate is None


# ─────────────────────────────────────────────────────────────
# UNIT TEST 3 — Retrieval
# ─────────────────────────────────────────────────────────────

def test_get_player_by_id_returns_correct_player(player_repo):
    """get_player_by_id trebuie să returneze exact player-ul creat."""
    name = _uid("Retrieve")
    created = player_repo.create_player(name)
    assert created is not None

    found = player_repo.get_player_by_id(created.player_id)
    assert found is not None
    assert found.player_id == created.player_id


def test_get_player_by_name_returns_correct_player(player_repo):
    """get_player_by_name trebuie să găsească player-ul după nume exact."""
    name = _uid("ByName")
    player_repo.create_player(name)

    found = player_repo.get_player_by_name(name)
    assert found is not None
    assert found.player_name == name


def test_get_player_by_id_returns_none_for_missing_id(player_repo):
    """ID inexistent trebuie să returneze None, nu o excepție."""
    result = player_repo.get_player_by_id(999_999)
    assert result is None


def test_total_player_count_increases_after_creation(player_repo):
    """Contorul total de playeri trebuie să crească după creare."""
    count_before = player_repo.get_total_player_count()
    player_repo.create_player(_uid("Count"))
    count_after = player_repo.get_total_player_count()
    assert count_after > count_before
