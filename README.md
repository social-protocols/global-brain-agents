# Global Brain Algorithm Validation (WIP)

>[!NOTE]
>This is an LLM agent simulation to test the efficacy of the [Global Brain](https://social-protocols.org/global-brain/) algorithm. This is still a work in progress.

## Workflow

To run the model, you have to provide an OpenAI API key.
If you use direnv, you can run `direnv allow` in the repository's directory and the contents of the file `.env.example` will be copied into a file called `.env`.
In this file, change the OPENAI_API_KEY variable to your key.
After running `direnv allow`, you should also have a dev shell which has all the necessary dependencies to run the model and explore the results.
The [just](https://github.com/casey/just) command runner is used to simplify workflows.

To run the model, execute:

```
just agents
```

To explore the model, run:

```
just shiny
```

This command starts a [shiny](https://shiny.posit.co/) app which runs on `localhost:3456`.

## Code Overview

- [ABM lines of code](notes/abm-stats.md)
- [shiny app lines of code](notes/shiny-app-stats.md)

