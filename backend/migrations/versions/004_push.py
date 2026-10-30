"""avisos push: dispositivos, preferencias y sitios vigilados

Revision ID: 004
Revises: 003
Create Date: 2026-10-31

Cada dispositivo es una URL de UnifiedPush con sus claves o un token de APNs.
Quien guarda un sitio recibe aviso de las historias que se publican cerca.
"""

from alembic import op

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE push_devices (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            platform    TEXT NOT NULL CHECK (platform IN ('webpush', 'apns')),
            endpoint    TEXT NOT NULL UNIQUE,
            p256dh      TEXT,
            auth        TEXT,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE INDEX idx_push_devices_user ON push_devices(user_id);

        ALTER TABLE users
            ADD COLUMN notify_own BOOLEAN NOT NULL DEFAULT true,
            ADD COLUMN notify_review BOOLEAN NOT NULL DEFAULT true;

        CREATE TABLE watched_places (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name        TEXT NOT NULL,
            location    GEOGRAPHY(Point, 4326) NOT NULL,
            radius_m    INTEGER NOT NULL CHECK (radius_m BETWEEN 200 AND 20000),
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        CREATE INDEX idx_watched_places_location ON watched_places USING GIST (location);
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DROP TABLE watched_places;
        ALTER TABLE users DROP COLUMN notify_own, DROP COLUMN notify_review;
        DROP TABLE push_devices;
        """
    )
