# Document Funkwhale

```{tip}
If you notice something missing in our documentation but don't feel confident contributing, submit a request [in our forum](https://forum.funkwhale.audio/t/documentation).
```

We try to document Funkwhale as thoroughly as possible to make it easy for users, admins, developers, and contributors to understand how everything works.

```{contents}
:local:
```

## Requirements

To work on Funkwhale's documentation, you need the following:

- [Git](https://git-scm.com): our version control system
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/): used to run our development environment
- A text editor of your choice

## Tooling

We use [Sphinx](https://www.sphinx-doc.org/) to generate our documentation. Sphinx provides excellent tooling for documenting Python projects. We write documentation in Markdown using the [MyST parser](https://myst-parser.readthedocs.io/en/latest/) to access Sphinx's features.

All documentation in Funkwhale is stored in the [main Funkwhale Git repository](https://dev.funkwhale.audio/funkwhale/funkwhale/-/tree/develop/docs).

## Style guide

We broadly follow the [Microsoft writing style guide](https://learn.microsoft.com/en-us/style-guide/welcome/) for language and tone. You should aim to keep your language simple and clear enough for readers of all levels. You can use a free tool like [Hemingway](https://hemingwayapp.com) to check the complexity of your sentences.

Here are some basic rules to follow:

1. Write in American English
2. Always use sentence casing for headers. For example: "Contribute to Funkwhale documentation" rather than "Contribute To Funkwhale Documentation"
3. Use contractions such as "don't" and "can't" to make your writing feel conversational. Only use the full words if you're trying to emphasize something

## Local setup

We provide a docker container for our documentation to make it easy to work on docs with a real-time preview. Once you install [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/), do the following to get a live preview:

1. Create a dummy `.env` file

   ```{code-block} sh
   touch .env
   ```

2. Create a dummy federation network

   ```{code-block} sh
   sudo docker network create federation
   ```

3. Build the container

   ```{code-block} sh
   sudo docker compose -f dev.yml build docs
   ```

4. Run the container

   ```{code-block} sh
   sudo docker compose -f dev.yml up docs
   ```

A real-time preview of the documentation is available on `http://0.0.0.1:8001`

## Redirects

If you move content to a new location, you need to set up a redirect. This ensures that any bookmarks or links posted before the change still take the user where they expect to go.

All redirects are stored in a {file}`redirects.txt` file. This is a simple text file containing one redirect per line. Each line contains the old URL and new URL as relative URLs.

In this example, the `architecture.html` file redirects to `https://docs.funkwhale.audio/developers/architecture.html`.

```{code-block} text
architecture.html, developers/architecture.html
```

## Contribution flow

Here's an example of the typical workflow for creating documentation:

1. [Create a fork](https://docs.gitlab.com/ee/user/project/repository/forking_workflow.html) of the Funkwhale codebase
2. Create a new branch for your documentation. In this example `my-branch-name` is the name of the branch

   ```{code-block} sh
   git checkout -b my-branch-name
   ```

3. Make your changes and verify them by running the [Docker container](#local-setup)
4. Add [redirects](#redirects) if required
5. Add a [changelog fragment](../developer_documentation/workflows/changelog.md)
6. Add your changed files to a commit

   ```{code-block} sh
   git add . # Add all changed files
   git add doc1.md doc2.md # Add specific files
   ```

7. Create a commit with a meaningful commit message

   ```{code-block} sh
   git commit -m "A meaningful commit message"
   ```

8. Push your changes to your fork

   ```{code-block} sh
   git push origin my-branch-name
   ```

9. Create a merge request in the [main Funkwhale repository](https://dev.funkwhale.audio/funkwhale/funkwhale)
