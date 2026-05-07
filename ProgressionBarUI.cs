using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System.Collections.Generic;

//claude da fara namespace
//we will see later if it crashes or nah

//This is the Unity UI script. 
//Attach it to a Canvas GameObject in your fleet/lobby scene.

// namespace BattleFleet.database{
    /// <summary>
    /// Attach to a Canvas GameObject.
    /// Shows fleet level, XP progress bar, and ship unlock milestones.
    /// </summary>
    public class ProgressionBarUI : MonoBehaviour
    {
        [Header("XP Bar")]
        public Slider          xpSlider;
        public TextMeshProUGUI levelLabel;     // "Fleet Level 4"
        public TextMeshProUGUI xpLabel;        // "240 / 400 XP"

        [Header("Ship Unlock Panel")]
        public Transform       shipListParent; // Vertical Layout Group
        public GameObject      shipRowPrefab;  // prefab with TextMeshProUGUI + lock icon

        private PlayerStatsRepository  _stats;
        private ShipUnlockRepository   _unlocks;
        private int                    _playerId;

        public void Initialise(DatabaseManager db, int playerId)
        {
            _stats    = new PlayerStatsRepository(db);
            _unlocks  = new ShipUnlockRepository(db);
            _playerId = playerId;
            Refresh();
        }

        public void Refresh()
        {
            RefreshXpBar();
            RefreshShipList();
        }

        // ── XP bar ────────────────────────────────────────────────────────────

        private void RefreshXpBar()
        {
            var (totalXp, xpStart, xpEnd) = _stats.GetProgressBarData(_playerId);
            int currentLevel = PlayerStatsRepository.CalculateLevel(totalXp);

            levelLabel.text = $"Fleet Level {currentLevel}";
            xpLabel.text    = $"{totalXp - xpStart} / {xpEnd - xpStart} XP";
            xpSlider.value  = (float)(totalXp - xpStart) / (xpEnd - xpStart);
        }

        // ── Ship unlock list ──────────────────────────────────────────────────

        private void RefreshShipList()
        {
            // Clear old rows
            foreach (Transform child in shipListParent)
                Destroy(child.gameObject);

            List<ShipUnlockStatus> statuses = _unlocks.GetAllShipStatusesForPlayer(_playerId);

            foreach (var s in statuses)
            {
                var row  = Instantiate(shipRowPrefab, shipListParent);
                var text = row.GetComponentInChildren<TextMeshProUGUI>();
                var icon = row.transform.Find("LockIcon")?.GetComponent<Image>();

                text.text  = $"{s.DisplayName}  —  {s.UnlockLabel}";
                text.color = s.IsUnlocked ? Color.white : Color.gray;

                if (icon != null)
                    icon.enabled = !s.IsUnlocked;
            }
        }
    }
// }