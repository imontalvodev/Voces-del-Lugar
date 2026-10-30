"""Filtro automático de lo que se guarda.

Sin moderadores a tiempo completo, cada historia pasa por aquí: la basura
obvia no se guarda, lo dudoso espera a que lo mire el admin y lo demás se
publica solo. Mira el título, el texto y el nombre de quien la cuenta; el
audio no se puede leer y pasa tal cual.
"""

import re

# Por qué una historia sigue en revisión. El cliente pone las palabras.
AWAITING_MEDIA = "awaiting_media"
LINK = "link"
CONTACT = "contact"
LANGUAGE = "language"
MANY = "many"
UNPUBLISHED = "unpublished"
REVIEW_REASONS = (AWAITING_MEDIA, LINK, CONTACT, LANGUAGE, MANY, UNPUBLISHED)

# Historias del mismo autor en una hora a partir de las cuales la siguiente espera.
MANY_PER_HOUR = 5

_VOWELS = set("aeiouyáéíóúü")
_ACCENTS = str.maketrans("áéíóúüàèìòù", "aeiouuaeiou")

_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")
_PHONE = re.compile(r"(?<!\d)(?:\+?\d[ .-]?){8,}\d(?!\d)")
_LINK = re.compile(
    r"https?://|www\.|\b[\w-]+\.(?:com|es|net|org|info|io|me|ly|xyz|online|site|shop|biz|co|eu|cat)\b",
    re.IGNORECASE,
)
_RUN = re.compile(r"([^\W\d_])\1{4,}")

# Insultos y palabras malsonantes, sin tildes. Lo que coincide no se borra:
# espera a que el admin decida, porque en una historia contada pueden salir.
_LANGUAGE = re.compile(
    r"\b(?:"
    r"puta|putas|puto|putos|hijoputa|mierda|mierdas|gilipollas|gilipolla|cabron|cabrona|cabrones|"
    r"coño|joder|jodete|polla|pollas|follar|maricon|maricones|marica|zorra|zorras|subnormal|"
    r"subnormales|retrasado|retrasada|idiota|idiotas|imbecil|imbeciles|capullo|capullos|"
    r"sudaca|sudacas|negrata|panchito|malparido|malnacido"
    r")\b"
)


def junk_reason(title: str, body: str | None, narrator: str | None) -> str | None:
    """Lo que hace que no se pueda guardar, dicho para quien la escribe."""
    if _letters(title) < 2 or _is_junk(title):
        return "El título no se entiende. Escribe unas palabras sobre la historia."
    if body and body.strip() and _is_junk(body):
        return "La historia no se entiende. Revisa el texto antes de guardarla."
    if narrator and narrator.strip() and _is_junk(narrator):
        return "El nombre de quien la cuenta no se entiende."
    return None


def hold_reason(title: str, body: str | None, narrator: str | None) -> str | None:
    """Por qué conviene que la mire alguien antes de publicarla."""
    text = " ".join(part for part in (title, body, narrator) if part)
    if _EMAIL.search(text) or _PHONE.search(text):
        return CONTACT
    if _LINK.search(text):
        return LINK
    if _LANGUAGE.search(text.lower().translate(_ACCENTS)):
        return LANGUAGE
    return None


def _letters(text: str) -> int:
    return sum(1 for char in text if char.isalpha())


def _is_junk(text: str) -> bool:
    if _RUN.search(text.lower()):
        return True
    words = re.findall(r"[^\W\d_]+", text.lower())
    if any(len(word) >= 7 and not _VOWELS.intersection(word) for word in words):
        return True
    visible = [char for char in text if not char.isspace()]
    letters = [char for char in visible if char.isalpha()]
    if len(visible) >= 20 and len(letters) < len(visible) / 2:
        return True
    return len(letters) >= 30 and len(set(letters)) <= 5
