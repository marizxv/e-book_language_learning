import os
import shutil
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional

from analyzer import estimate_user_level, word_info, word_to_cefr
from db import get_db, init_db
from epub_parser import parse_epub
from translator import translate

app = FastAPI(
    title="LinguaBook API",
    description="Backend for the e-book language learning mobile app.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DEEPL_KEY: Optional[str] = os.getenv("DEEPL_API_KEY")


@app.on_event("startup")
def startup():
    init_db()


# ── Models ──────────────────────────────────────────────────────────────────

class TranslateRequest(BaseModel):
    word: str
    context: str
    source_lang: str = "en"
    target_lang: str = "pl"


class LevelRequest(BaseModel):
    words: List[str]
    lang: str = "en"


class VocabularyAdd(BaseModel):
    word: str
    translation: str
    context: Optional[str] = None
    cefr_level: Optional[str] = None
    source_lang: str = "en"
    target_lang: str = "pl"


class FlashcardResult(BaseModel):
    known: bool


# ── Endpoints ────────────────────────────────────────────────────────────────

@app.post("/translate", summary="Translate a word in context")
async def translate_word(req: TranslateRequest):
    """
    Translates the word using the full sentence as context.
    Returns both the word translation (for flashcard) and the
    translated sentence (so the user sees meaning in context).
    Also returns the CEFR difficulty level of the word.
    """
    result = await translate(
        req.word, req.context, req.source_lang, req.target_lang, DEEPL_KEY
    )
    result["cefr_level"] = word_to_cefr(req.word, req.source_lang)
    return result


@app.post("/analyze-level", summary="Estimate user's language level")
def analyze_level(req: LevelRequest):
    """
    Given a list of words the user looked up (i.e. didn't know),
    estimates their current CEFR level and returns a breakdown
    of how many words fall at each difficulty tier.
    """
    return estimate_user_level(req.words, req.lang)


@app.get("/word/{word}", summary="Get frequency and CEFR info for one word")
def get_word_info(word: str, lang: str = "en"):
    return word_info(word, lang)


# ── Vocabulary ───────────────────────────────────────────────────────────────

@app.post("/vocabulary", summary="Save a word to the personal dictionary")
def add_word(entry: VocabularyAdd):
    with get_db() as conn:
        cursor = conn.execute(
            """INSERT INTO vocabulary
               (word, translation, context, cefr_level, source_lang, target_lang)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (entry.word, entry.translation, entry.context,
             entry.cefr_level, entry.source_lang, entry.target_lang),
        )
        conn.commit()
        return {"id": cursor.lastrowid, "message": "Saved"}


@app.get("/vocabulary", summary="List all saved words")
def list_vocabulary(source_lang: str = "en", target_lang: str = "pl"):
    with get_db() as conn:
        rows = conn.execute(
            """SELECT * FROM vocabulary
               WHERE source_lang=? AND target_lang=?
               ORDER BY created_at DESC""",
            (source_lang, target_lang),
        ).fetchall()
        return [dict(r) for r in rows]


@app.delete("/vocabulary/{word_id}", summary="Delete a word from dictionary")
def delete_word(word_id: int):
    with get_db() as conn:
        conn.execute("DELETE FROM vocabulary WHERE id=?", (word_id,))
        conn.commit()
        return {"message": "Deleted"}


# ── Flashcards ────────────────────────────────────────────────────────────────

@app.get("/flashcards", summary="Get words due for review")
def get_flashcards(source_lang: str = "en", target_lang: str = "pl"):
    """Returns words ordered by fewest reviews first (learn new words first)."""
    with get_db() as conn:
        rows = conn.execute(
            """SELECT id, word, translation, context, cefr_level, review_count
               FROM vocabulary
               WHERE source_lang=? AND target_lang=? AND known=0
               ORDER BY review_count ASC, created_at ASC""",
            (source_lang, target_lang),
        ).fetchall()
        return [dict(r) for r in rows]


@app.patch("/flashcards/{word_id}", summary="Mark flashcard as known or unknown")
def review_flashcard(word_id: int, result: FlashcardResult):
    with get_db() as conn:
        conn.execute(
            "UPDATE vocabulary SET known=?, review_count=review_count+1 WHERE id=?",
            (1 if result.known else 0, word_id),
        )
        conn.commit()
        return {"message": "Updated"}


# ── EPUB ──────────────────────────────────────────────────────────────────────

@app.post("/epub/upload", summary="Upload an EPUB and extract its text")
async def upload_epub(file: UploadFile = File(...)):
    """
    Accepts an EPUB file, parses it, and returns the title, author,
    chapter list, and total word count. Chapter text is included so
    the app can render the reader immediately without a second request.
    """
    if not file.filename or not file.filename.endswith(".epub"):
        raise HTTPException(status_code=400, detail="Only .epub files are accepted.")

    with tempfile.NamedTemporaryFile(delete=False, suffix=".epub") as tmp:
        shutil.copyfileobj(file.file, tmp)
        tmp_path = tmp.name

    try:
        return parse_epub(tmp_path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to parse EPUB: {exc}")
    finally:
        os.unlink(tmp_path)
