using OpenAI

SECRET_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo"
DATABASE_PATH = get(ENV, "DATABASE_PATH", "data/results.db")

db = SQLite.DB(DATABASE_PATH)
DBInterface.execute(db, """
    CREATE TABLE IF NOT EXISTS personas (
          id     INTEGER PRIMARY KEY
        , name   TEXT
        , age    INTEGER
        , gender TEXT
        , job    TEXT
        , traits TEXT
    )
""")


