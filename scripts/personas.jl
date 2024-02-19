using OpenAI
using JSON
using SQLite

SECRET_KEY = get(ENV, "OPENAI_API_KEY", "")
LLM = "gpt-3.5-turbo-1106"
DATABASE_PATH = get(ENV, "DATABASE_PATH", "data/results.db")

TOOLS = [
    Dict(
        "type" => "function",
        "function" => Dict(
            "name" => "create_agent_with_persona",
            "description" => "Create an agent with a persona with given attributes.",
            "parameters" => Dict(
                "type" => "object",
                "properties" => Dict(
                    "name" => Dict(
                        "type" => "string",
                        "description" => "The agent's first name",
                    ),
                    "age" => Dict(
                        "type" => "number",
                        "enum" => collect(0:100),
                        "description" => "A number between 0 and 100",
                    ),
                    "gender" => Dict(
                        "type" => "string",
                        "enum" => ["m", "f", "d"],
                        "description" => "m for male, f for female, d for diverse",
                    ),
                    "job" => Dict(
                        "type" => "string",
                        "description" => "The agent's occupation",
                    ),
                    "traits" => Dict(
                        "type" => "string",
                        "description" => "A description of the agent's in 100 to 200 characters",
                    ),
                ),
            ),
            "required" => ["name", "age", "gender", "job", "traits"],
        )
    )
]

messages = [
    Dict(
        "role" => "system",
        "content" => """
            Personas should be as diverse as possible in terms of all of their attributes.
        """
    ),
    Dict(
        "role" => "system",
        "content" => """
            The personas' jobs should reflect different levels of eductation.
        """
    ),
    Dict(
        "role" => "system",
        "content" => """
            Personas' ages should cover a wide range.
        """
    ),
    Dict(
        "role" => "system",
        "content" => """
            Some personas should be good people and some can be assholes.
        """
    ),
]

task_message = Dict(
    "role" => "user",
    "content" => "Please create an agent."
)
task_message_asshole = Dict(
    "role" => "user",
    "content" => "Please create an agent. Make sure he or she is a real asshole."
)

p_asshole = 0.2

personas = []

function is_valid(persona::Dict)::Bool
    return isempty(setdiff(keys(persona), Set(["name", "age", "gender", "job", "traits"])))
end

for i in 1:10
    this_iter_messages = rand() < p_asshole ? [messages; task_message_asshole] : [messages; task_message]
    r = create_chat(
        SECRET_KEY,
        LLM,
        this_iter_messages;
        tools = TOOLS,
        tool_choice = Dict(
            "type" => "function",
            "function" => Dict(
                "name" => "create_agent_with_persona",
            ),
        ),
    )
    tool_call = r.response[:choices][begin][:message][:tool_calls][begin]
    created_persona = tool_call[:function][:arguments]
    push!(
        messages,
        Dict(
            "role" => "system",
            "content" => """
                The following agent already exists:
                $created_persona
                Make sure to consider the diversity of the personas and don't create this or a similar agent again.
            """,
        ),
    )
    persona = JSON.parse(created_persona)
    if !is_valid(persona)
        @warn "Invalid persona: $persona"
        continue
    end
    push!(personas, persona)
end

db = SQLite.DB(DATABASE_PATH)
DBInterface.execute(db, "DROP TABLE IF EXISTS personas")
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

for (idx, persona) in enumerate(personas)
    DBInterface.execute(
        db,
        """
            INSERT INTO personas (id, name, age, gender, job, traits)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
        (idx, persona["name"], persona["age"], persona["gender"], persona["job"], persona["traits"]),
    )
end

