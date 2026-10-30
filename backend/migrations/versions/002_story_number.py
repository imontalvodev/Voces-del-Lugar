"""número de ficha correlativo

Revision ID: 002
Revises: 001
Create Date: 2026-10-30

Cada historia lleva un número que se ve como «Nº 0142». Las que ya existen se
numeran por antigüedad; las nuevas toman el siguiente de la secuencia.
"""

from alembic import op

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE stories ADD COLUMN number INTEGER;
        CREATE SEQUENCE stories_number_seq OWNED BY stories.number;

        UPDATE stories s
        SET number = ordered.n
        FROM (
            SELECT id, row_number() OVER (ORDER BY created_at, id) AS n
            FROM stories
        ) ordered
        WHERE s.id = ordered.id;

        SELECT setval(
            'stories_number_seq',
            COALESCE((SELECT max(number) FROM stories), 0) + 1,
            false
        );

        ALTER TABLE stories
            ALTER COLUMN number SET DEFAULT nextval('stories_number_seq'),
            ALTER COLUMN number SET NOT NULL,
            ADD CONSTRAINT stories_number_key UNIQUE (number);
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE stories DROP COLUMN number")
