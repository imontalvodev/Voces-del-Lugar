"""esquema inicial postgis

Revision ID: 001
Revises:
Create Date: 2026-09-22
"""

from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE EXTENSION IF NOT EXISTS postgis;

        CREATE TABLE users (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email           TEXT UNIQUE NOT NULL,
            password_hash   TEXT NOT NULL,
            display_name    TEXT NOT NULL,
            role            TEXT NOT NULL DEFAULT 'contributor'
                            CHECK (role IN ('contributor', 'curator', 'admin')),
            preferred_lang  TEXT DEFAULT 'es',
            created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE TABLE places (
            id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name            TEXT NOT NULL,
            place_type      TEXT NOT NULL
                            CHECK (place_type IN ('barrio', 'pueblo', 'edificio', 'paraje', 'otro')),
            description     TEXT,
            location        GEOGRAPHY(Point, 4326) NOT NULL,
            created_by      UUID REFERENCES users(id),
            created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE INDEX idx_places_location ON places USING GIST (location);

        CREATE TABLE stories (
            id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            place_id            UUID NOT NULL REFERENCES places(id) ON DELETE CASCADE,
            author_id           UUID NOT NULL REFERENCES users(id),
            narrator_name       TEXT,
            narrator_relation   TEXT,
            title               TEXT NOT NULL,
            body                TEXT,
            transcript          TEXT,
            narrator_consent    BOOLEAN NOT NULL,
            narrator_deceased   BOOLEAN NOT NULL DEFAULT false,
            consent_recorded_at TIMESTAMPTZ,
            category            TEXT NOT NULL
                                CHECK (category IN ('anecdota', 'leyenda', 'oficio', 'tradicion', 'evento', 'otro')),
            decade_approx       INTEGER,
            original_language   TEXT DEFAULT 'es',
            license             TEXT NOT NULL DEFAULT 'CC-BY-SA-4.0'
                                CHECK (license IN ('CC-BY-SA-4.0', 'CC-BY-4.0', 'CC0-1.0')),
            status              TEXT NOT NULL DEFAULT 'draft'
                                CHECK (status IN ('draft', 'pending_review', 'published', 'rejected')),
            created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
            published_at        TIMESTAMPTZ
        );

        CREATE INDEX idx_stories_place ON stories(place_id);
        CREATE INDEX idx_stories_status ON stories(status);

        CREATE TABLE media_assets (
            id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            story_id            UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
            media_type          TEXT NOT NULL CHECK (media_type IN ('audio', 'photo')),
            storage_key         TEXT NOT NULL,
            duration_seconds    INTEGER,
            processing_status   TEXT NOT NULL DEFAULT 'pending'
                                CHECK (processing_status IN ('pending', 'processing', 'done', 'failed')),
            created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE INDEX idx_media_story ON media_assets(story_id);

        CREATE TABLE tags (
            id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name    TEXT UNIQUE NOT NULL
        );

        CREATE TABLE story_tags (
            story_id    UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
            tag_id      UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (story_id, tag_id)
        );
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DROP TABLE IF EXISTS story_tags;
        DROP TABLE IF EXISTS tags;
        DROP TABLE IF EXISTS media_assets;
        DROP TABLE IF EXISTS stories;
        DROP TABLE IF EXISTS places;
        DROP TABLE IF EXISTS users;
        """
    )
