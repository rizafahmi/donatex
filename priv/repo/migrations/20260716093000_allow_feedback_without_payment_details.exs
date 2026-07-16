defmodule Donatex.Repo.Migrations.AllowFeedbackWithoutPaymentDetails do
  use Ecto.Migration

  def up do
    recreate_donations_table("")
  end

  def down do
    recreate_donations_table("NOT NULL")
  end

  defp recreate_donations_table(payment_nullability) do
    execute("""
    CREATE TABLE donations_replacement (
      id TEXT PRIMARY KEY,
      mayar_transaction_id TEXT #{payment_nullability},
      donor_name TEXT NOT NULL,
      amount INTEGER #{payment_nullability},
      message TEXT,
      status TEXT DEFAULT 'pending' NOT NULL,
      alerted INTEGER DEFAULT false NOT NULL,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      reaction TEXT
    )
    """)

    execute("""
    INSERT INTO donations_replacement
      (id, mayar_transaction_id, donor_name, amount, message, status, alerted, inserted_at, updated_at, reaction)
    SELECT
      id, mayar_transaction_id, donor_name, amount, message, status, alerted, inserted_at, updated_at, reaction
    FROM donations
    """)

    execute("DROP TABLE donations")
    execute("ALTER TABLE donations_replacement RENAME TO donations")

    create unique_index(:donations, [:mayar_transaction_id])

    create index(:donations, [:status, :alerted, :inserted_at, :id],
             name: :donations_recovery_queue_idx
           )

    create index(:donations, [:inserted_at, :id], name: :donations_order_idx)
  end
end
