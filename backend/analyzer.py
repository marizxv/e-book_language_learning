import statistics
from typing import List
from wordfreq import zipf_frequency

CEFR_LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]

# Zipf scale: "the" ~8.5, "house" ~5.7, "sufficient" ~3.8, "ephemeral" ~2.5
_THRESHOLDS = [6.0, 5.0, 4.0, 3.0, 2.0]


def word_to_cefr(word: str, lang: str = "en") -> str:
    zipf = zipf_frequency(word.lower(), lang)
    for i, threshold in enumerate(_THRESHOLDS):
        if zipf >= threshold:
            return CEFR_LEVELS[i]
    return "C2"


def estimate_user_level(unknown_words: List[str], lang: str = "en") -> dict:
    if not unknown_words:
        return {"level": "B1", "confidence": 0.0, "breakdown": {}}

    level_indices = [CEFR_LEVELS.index(word_to_cefr(w, lang)) for w in unknown_words]
    breakdown = {lvl: level_indices.count(i) for i, lvl in enumerate(CEFR_LEVELS)}

    # User's level is one step below the median difficulty they struggle with
    median_index = statistics.median(level_indices)
    user_index = max(0, round(median_index) - 1)

    # Confidence grows with sample size, saturates at 30 words
    confidence = round(min(1.0, len(unknown_words) / 30), 2)

    return {
        "level": CEFR_LEVELS[user_index],
        "confidence": confidence,
        "breakdown": breakdown,
        "total_analyzed": len(unknown_words),
    }


def word_info(word: str, lang: str = "en") -> dict:
    zipf = zipf_frequency(word.lower(), lang)
    return {
        "word": word,
        "lang": lang,
        "zipf_frequency": round(zipf, 2),
        "cefr_level": word_to_cefr(word, lang),
        "is_common": zipf >= 4.0,
    }
