# tests/test_acceptance_battle_flow.py
#
# ACCEPTANCE TESTS — fluxuri complete din perspectiva jucătorului
#
# „Acceptance" (sau „end-to-end") înseamnă că testăm scenarii reale,
# nu funcții izolate. Fiecare test simulează o acțiune completă a
# utilizatorului: „crează cont → joacă bătălie → verifică statistici".
#
# Diferența față de unit tests:
#   Unit test:       test_create_player_returns_player_object  ← o funcție, un comportament
#   Acceptance test: test_player_wins_battle_and_stats_update  ← un scenariu complet
#
# Rulare locală:
#   pytest tests/ -v
#   pytest tests/test_acceptance_battle_flow.py -v   # doar acestea

import time
import math
import pytest
from database.models import BattleRecord
from database_manager import DatabaseManager
from database.player_repository import PlayerRepository
from database.player_stats_repository import PlayerStatsRepository


# ─────────────────────────────────────────────────────────────
# Fixtures (identice cu cele din unit tests — fiecare test
# primește o bază de date fresh, izolată)
# ─────────────────────────────────────────────────────────────

@pytest.fixture
def db():
    manager = DatabaseManager(":memory:")
    manager.initialize()
    yield manager
    manager.close()


@pytest.fixture
def player_repo(db):
    return PlayerRepository(db)


@pytest.fixture
def stats_repo(db):
    return PlayerStatsRepository(db)


def _uid(base: str) -> str:
    return f"Test_{base}_{int(time.time() * 1_000_000)}"


# ─────────────────────────────────────────────────────────────
# ACCEPTANCE SCENARIO 1
# Un jucător nou câștigă prima bătălie
# ─────────────────────────────────────────────────────────────

def test_new_player_wins_first_battle_stats_are_updated(player_repo, stats_repo):
    """
    SCENARIU: Jucătorul nou înregistrează o victorie.
    AȘTEPTAT: TotalBattles=1, TotalWins=1, ShipsDestroyed=3, ShipsLost=1
    """
    # Pas 1 — jucătorul se înregistrează
    player = player_repo.create_player(_uid("Winner"))
    assert player is not None, "Crearea playerului a eșuat"

    # Pas 2 — joacă și câștigă
    battle = BattleRecord(
        opponent_name    = "Admiral Tanaka (AI)",
        result           = 1,          # 1 = jucătorul câștigă
        ships_destroyed  = 3,
        ships_lost       = 1,
        difficulty_level = "Normal",
        battle_mode      = "SkirmishBattle",
    )
    success = stats_repo.record_battle_result(player.player_id, battle)
    assert success is True, "record_battle_result a returnat False"

    # Pas 3 — verifică statisticile actualizate
    stats = stats_repo.get_player_stats(player.player_id)
    assert stats is not None

    assert stats.total_battles         == 1
    assert stats.total_wins            == 1
    assert stats.total_ships_destroyed == 3
    assert stats.total_ships_lost      == 1


def test_win_creates_battle_history_row(player_repo, stats_repo, db):
    """
    SCENARIU: O victorie trebuie să genereze un rând în BattleHistory.
    AȘTEPTAT: rândul există cu Result=1 și OpponentName corect.
    """
    player = player_repo.create_player(_uid("HistoryCheck"))
    assert player is not None

    battle = BattleRecord(
        opponent_name   = "Admiral Tanaka (AI)",
        result          = 1,
        ships_destroyed = 3,
        ships_lost      = 1,
    )
    stats_repo.record_battle_result(player.player_id, battle)

    rows = db.execute_reader(
        "SELECT * FROM BattleHistory WHERE PlayerID = ?",
        (player.player_id,)
    )
    assert len(rows) == 1,                              "BattleHistory trebuie să aibă exact 1 rând"
    assert rows[0].get("Result") == 1,                  "Result trebuie să fie 1 (victorie)"
    assert "Tanaka" in str(rows[0].get("OpponentName", "")), \
           "OpponentName trebuie să conțină 'Tanaka'"


# ─────────────────────────────────────────────────────────────
# ACCEPTANCE SCENARIO 2
# Jucătorul joacă 3 bătălii: Win, Loss, Draw
# ─────────────────────────────────────────────────────────────

def test_full_three_battle_sequence_wld(player_repo, stats_repo):
    """
    SCENARIU: Jucătorul joacă 3 bătălii consecutive — victorie, înfrângere, egalitate.
    AȘTEPTAT: agregare corectă W/L/D=1/1/1 și win-rate ≈ 33.3%
    """
    player = player_repo.create_player(_uid("WLD"))
    assert player is not None
    pid = player.player_id

    # Bătălia 1 — victorie
    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=1, ships_destroyed=3, ships_lost=1
    ))
    # Bătălia 2 — înfrângere
    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=2, ships_destroyed=0, ships_lost=2
    ))
    # Bătălia 3 — egalitate
    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=0, ships_destroyed=1, ships_lost=1
    ))

    stats = stats_repo.get_player_stats(pid)
    assert stats is not None

    assert stats.total_battles == 3,  "Trebuie 3 bătălii totale"
    assert stats.total_wins    == 1,  "Trebuie 1 victorie"
    assert stats.total_losses  == 1,  "Trebuie 1 înfrângere"
    assert stats.total_draws   == 1,  "Trebuie 1 egalitate"

    win_rate = stats.total_wins / stats.total_battles * 100.0
    assert math.isclose(win_rate, 33.333, abs_tol=0.1), \
           f"Win rate trebuie să fie ≈33.3%, primit {win_rate:.2f}%"


def test_ships_accumulate_across_multiple_battles(player_repo, stats_repo):
    """
    SCENARIU: Navele distruse și pierdute se acumulează corect pe mai multe bătălii.
    AȘTEPTAT: TotalShipsDestroyed=4, TotalShipsLost=4
    """
    player = player_repo.create_player(_uid("Ships"))
    assert player is not None
    pid = player.player_id

    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=1, ships_destroyed=3, ships_lost=1
    ))
    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=2, ships_destroyed=0, ships_lost=2
    ))
    stats_repo.record_battle_result(pid, BattleRecord(
        opponent_name="CPU", result=0, ships_destroyed=1, ships_lost=1
    ))

    stats = stats_repo.get_player_stats(pid)
    assert stats is not None
    assert stats.total_ships_destroyed == 4, "TotalShipsDestroyed trebuie să fie 4"
    assert stats.total_ships_lost      == 4, "TotalShipsLost trebuie să fie 4"


# ─────────────────────────────────────────────────────────────
# ACCEPTANCE SCENARIO 3
# Gestionarea erorilor nu aruncă excepții neașteptate
# ─────────────────────────────────────────────────────────────

def test_stats_for_nonexistent_player_returns_none(stats_repo):
    """
    SCENARIU: Cerere statistici pentru un player inexistent.
    AȘTEPTAT: None returnat curat, fără crash / excepție.
    """
    stats = stats_repo.get_player_stats(-1)
    assert stats is None


def test_get_nonexistent_player_by_id_returns_none(player_repo):
    """
    SCENARIU: Căutare după un ID care nu există în baza de date.
    AȘTEPTAT: None, nu KeyError sau altă excepție.
    """
    result = player_repo.get_player_by_id(999_999)
    assert result is None


def test_register_two_players_and_each_has_isolated_stats(player_repo, stats_repo):
    """
    SCENARIU: Doi jucători se înregistrează; bătăliile unuia nu afectează pe celălalt.
    AȘTEPTAT: fiecare player are statisticile sale izolate.
    """
    alice = player_repo.create_player(_uid("Alice"))
    bob   = player_repo.create_player(_uid("Bob"))
    assert alice is not None and bob is not None

    # Alice câștigă 2 bătălii
    for _ in range(2):
        stats_repo.record_battle_result(alice.player_id, BattleRecord(
            opponent_name="CPU", result=1, ships_destroyed=1, ships_lost=0
        ))

    # Bob nu a jucat nimic
    alice_stats = stats_repo.get_player_stats(alice.player_id)
    bob_stats   = stats_repo.get_player_stats(bob.player_id)

    assert alice_stats.total_battles == 2, "Alice trebuie să aibă 2 bătălii"
    assert bob_stats.total_battles   == 0, "Bob trebuie să aibă 0 bătălii"
