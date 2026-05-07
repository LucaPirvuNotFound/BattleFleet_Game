using System;
using System.Data;
using System.Collections.generic;
using UnityEngine;
using Mono.data.Sqlite

//wtf???
namespace BattleFleet.Database{
    public class ShipUnlockRepository{
        private readonly DatabaseManager _db;

        public ShipUnlockRepository(DatabaseManager db){ _db = db;}
        //_______________Core unlock check_________________
        /// <summary>Returns true if the player's fleet level meets the ship's requirement.</summary>
        public bool IsShipUnlocked(int playerId, string shipType)
        {
            using var conn = _db.GetConnection();
            conn.Open();

            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT 
                    CASE WHEN p.fleet_level >= s.required_level THEN 1 ELSE 0 END
                FROM players p
                JOIN ship_unlock_requirements s ON s.ship_type = @shipType
                WHERE p.id = @playerId;";

            cmd.Parameters.AddWithValue("@shipType",  shipType);
            cmd.Parameters.AddWithValue("@playerId",  playerId);

            var result = cmd.ExecuteScalar();
            return result != null && (long)result == 1;
        }

        // ── Full status list (used by fleet selection UI) ──────────────────────

        /// <summary>
        /// Returns every ship with its unlock status for a given player.
        /// Use this to populate the ship selection screen.
        /// </summary>
        public List<ShipUnlockStatus> GetAllShipStatusesForPlayer(int playerId)
        {
            var statuses = new List<ShipUnlockStatus>();

            using var conn = _db.GetConnection();
            conn.Open();

            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT 
                    s.ship_type,
                    s.display_name,
                    s.required_level,
                    s.description,
                    CASE WHEN p.fleet_level >= s.required_level THEN 1 ELSE 0 END AS is_unlocked
                FROM ship_unlock_requirements s
                JOIN players p ON p.id = @playerId
                ORDER BY s.required_level ASC;";

            cmd.Parameters.AddWithValue("@playerId", playerId);

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                statuses.Add(new ShipUnlockStatus
                {
                    ShipType      = reader.GetString(0),
                    DisplayName   = reader.GetString(1),
                    RequiredLevel = reader.GetInt32(2),
                    Description   = reader.GetString(3),
                    IsUnlocked    = reader.GetInt32(4) == 1
                });
            }

            return statuses;
        }

        // ── All requirements (used by progression display / tooltip) ───────────

        public List<ShipUnlockRequirement> GetAllRequirements()
        {
            var list = new List<ShipUnlockRequirement>();

            using var conn = _db.GetConnection();
            conn.Open();

            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                SELECT ship_type, required_level, display_name, description
                FROM ship_unlock_requirements
                ORDER BY required_level ASC;";

            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                list.Add(new ShipUnlockRequirement
                {
                    ShipType      = reader.GetString(0),
                    RequiredLevel = reader.GetInt32(1),
                    DisplayName   = reader.GetString(2),
                    Description   = reader.GetString(3)
                });
            }

            return list;
        }
    }
}