<h1 align="center" style="border-bottom: none">
    <div>Global Brain Algorithm Validation Experiments </div>
    <div><span style="font-style: italic">(Public Archive)</span></div>
</h1>

>[!NOTE]
>*This repository contains early validation experiments for the [Global Brain algorithm](https://social-protocols.org/global-brain/). This repository will be archived because we continue experimentation elsewhere: You can see current development and experimentation [here](https://github.com/social-protocols/GlobalBrainService.jl).*

## GPT Agent Simulation 

>[!CAUTION]
>Please read the code before you add your OpenAI API key and execute anything. This model makes calls to the OpenAI API, so a cost is involved in running this model. It is currently very small, but you should verify how the module makes calls to the API anyways.

The `src` folder contains a Julia module that simulates agents with different personas generated with the OpenAI API.
These agents can be used in an agent-based model that let's them interact with a system which runs the Global Brain algorithm.

To run the model, you have to provide an OpenAI API key by putting it into your `.env` file (see `.env.example`).
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
just agents-app
```

To generate personas, run:

```
just personas
```

## Prototype and Simulations App

The `prototype-simulations-app` folder contains a shiny app that uses d3 to visualize the results of the Global Brain algorithm.

To run it, use:

```
just shiny
```
