import re
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup


def parse_epub(file_path: str) -> dict:
    book = epub.read_epub(file_path)

    chapters = []
    for item in book.get_items():
        if item.get_type() != ebooklib.ITEM_DOCUMENT:
            continue
        soup = BeautifulSoup(item.get_content(), "html.parser")
        text = soup.get_text(separator=" ", strip=True)
        text = re.sub(r"\s+", " ", text).strip()
        if len(text) < 100:
            continue
        chapters.append({
            "id": item.get_id(),
            "name": item.get_name(),
            "text": text,
            "word_count": len(text.split()),
        })

    creators = book.get_metadata("DC", "creator")
    author = creators[0][0] if creators else "Unknown"

    return {
        "title": book.title or "Unknown",
        "author": author,
        "chapters": chapters,
        "total_words": sum(c["word_count"] for c in chapters),
        "chapter_count": len(chapters),
    }
