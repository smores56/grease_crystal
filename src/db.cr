require "dotenv"
require "mysql"

Dotenv.load
TRANSACTION = (DB.connect ENV["DATABASE_URL"]).begin_transaction
CONN        = TRANSACTION.connection
