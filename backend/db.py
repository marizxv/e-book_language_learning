import sqlite3
from contextlib import contextmanager
from pathlib import Path

DB_PATH = Path("vocabulary.db")


def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS vocabulary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT NOT NULL,
                translation TEXT,
                context TEXT,
                cefr_level TEXT,
                source_lang TEXT DEFAULT 'en',
                target_lang TEXT DEFAULT 'pl',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                review_count INTEGER DEFAULT 0,
                known INTEGER DEFAULT 0
            )
        """)
        conn.commit()


@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()
