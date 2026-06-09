# models.py
# Python equivalents of the GDScript BattleFleetModels inner classes.
# Used by PlayerRepository and PlayerStatsRepository.

from dataclasses import dataclass, field


@dataclass
class Player:
    player_id: int = 0
    player_name: str = ""
    email: str = ""
    password_hash: str = ""
    created_date: str = ""
    last_played_date: str = ""
    is_active: bool = True
    elo: int = 0


@dataclass
class PlayerStats:
    stat_id: int = 0
    player_id: int = 0
    total_battles: int = 0
    total_wins: int = 0
    total_losses: int = 0
    total_draws: int = 0
    average_accuracy: float = 0.0
    total_ships_destroyed: int = 0
    total_ships_lost: int = 0
    last_updated: str = ""
    battleship_kills: int = 0
    battleship_deaths: int = 0
    battleship_accuracy: int =0
    cruiser_kills: int =0
    cruiser_deaths: int =0
    cruiser_accuracy: int =0
    destroyer_kills: int =0
    destroyer_deaths: int =0
    destroyer_accuracy: int=0
    corvette_kills: int = 0
    corvette_deaths: int =0
    corvette_accuracy: int=0
    torpedo_boat_kills: int =0
    torpedo_boat_deaths: int =0
    torpedo_boat_accuracy: int =0



@dataclass
class BattleRecord:
    opponent_name: str = ""
    result: int = 0            # "Win" | "Loss" | "Draw"
    ships_destroyed: int = 0
    ships_lost: int = 0
    difficulty_level: str = "Normal"
    battle_mode: str = "SkirmishBattle"

@dataclass
class Move:
    move_id: int =0
    turn_number: int = 0
    match_id: int =0
    player_id: int = 0
    type: str = ""
    distance: float = 0.0
    angle: float = 0.0
    position: str = ""
