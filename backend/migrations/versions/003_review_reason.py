"""por qué una historia sigue en revisión

Revision ID: 003
Revises: 002
Create Date: 2026-10-30

Con la publicación automática, lo que el filtro no deja pasar solo o lo que
espera su audio queda en revisión con un motivo, para que el admin sepa qué
mirar.
"""

from alembic import op

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE stories ADD COLUMN review_reason TEXT
            CHECK (review_reason IN (
                'awaiting_media', 'link', 'contact', 'language', 'many', 'unpublished'
            ));
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE stories DROP COLUMN review_reason")
