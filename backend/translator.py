import httpx
from typing import Optional


async def translate(
    word: str,
    context: str,
    source_lang: str,
    target_lang: str,
    deepl_key: Optional[str] = None,
) -> dict:
    if deepl_key:
        return await _deepl(word, context, source_lang, target_lang, deepl_key)
    return await _mymemory(word, context, source_lang, target_lang)


def _fix_encoding(text: str) -> str:
    """MyMemory sometimes sends Latin-2 bytes mislabelled as UTF-8; try to repair."""
    try:
        return text.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return text


async def _mymemory(word: str, context: str, source_lang: str, target_lang: str) -> dict:
    lang_pair = f"{source_lang}|{target_lang}"
    async with httpx.AsyncClient(timeout=10.0) as client:
        # Translate the full sentence for context-aware result
        r1 = await client.get(
            "https://api.mymemory.translated.net/get",
            params={"q": context, "langpair": lang_pair},
        )
        raw_context = r1.json().get("responseData", {}).get("translatedText", "")
        context_translation = _fix_encoding(raw_context)

        # Translate the word alone for the flashcard
        r2 = await client.get(
            "https://api.mymemory.translated.net/get",
            params={"q": word, "langpair": lang_pair},
        )
        raw_word = r2.json().get("responseData", {}).get("translatedText", word)
        word_translation = _fix_encoding(raw_word)

    return {
        "word": word,
        "translation": word_translation,
        "context_translation": context_translation,
        "source": "mymemory",
    }


async def _deepl(word: str, context: str, source_lang: str, target_lang: str, key: str) -> dict:
    headers = {"Authorization": f"DeepL-Auth-Key {key}"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        r1 = await client.post(
            "https://api-free.deepl.com/v2/translate",
            headers=headers,
            json={"text": [context], "source_lang": source_lang.upper(), "target_lang": target_lang.upper()},
        )
        context_translation = r1.json()["translations"][0]["text"]

        r2 = await client.post(
            "https://api-free.deepl.com/v2/translate",
            headers=headers,
            json={"text": [word], "source_lang": source_lang.upper(), "target_lang": target_lang.upper()},
        )
        word_translation = r2.json()["translations"][0]["text"]

    return {
        "word": word,
        "translation": word_translation,
        "context_translation": context_translation,
        "source": "deepl",
    }
