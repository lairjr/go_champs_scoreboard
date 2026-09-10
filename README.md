# GoChampsScoreboard

A real-time scoreboard application built with Phoenix LiveView for managing and displaying live scores for tournaments and competitions. This application provides an intuitive interface for score tracking and live updates that keep players, officials, and spectators informed in real-time.

## Features

- Real-time score updates using Phoenix LiveView
- Tournament and competition management
- Live score tracking and display
- Responsive design for various devices
- WebSocket-based real-time communication
- Interactive React components integrated with Phoenix LiveView

## Documentation

- **[React Implementation Guide](REACT_IMPLEMENTATION.md)** - Comprehensive guide for developing React components, including architecture patterns, Phoenix LiveView integration, and best practices
- **[Mix Tasks](lib/mix/tasks/README.md)** - Custom Mix tasks for administrative, data-export, and maintenance operations (e.g. exporting a real game as an anonymized regression fixture)

## Getting Started

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Bring up the shared RabbitMQ broker (see [RabbitMQ topology](#rabbitmq-topology) below)
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## RabbitMQ topology

`priv/rabbitmq/definitions.json` is a verbatim copy of `rabbitmq/definitions.json`
in [go-champs-local-infra](https://github.com/go-champs-org/go-champs-local-infra),
which is the source of truth for every environment. Never edit the copy — change
it there, re-vendor it here, and open both pull requests. CI fails the build when
the two diverge.

The file is applied over AMQP, never through the management API: an import needs
the `administrator` tag that the CloudAMQP user does not have, and it returns
`204 success` even when the broker disagrees with what was imported.

**In every deployed environment**, the release phase runs `mix rabbitmq.declare`
(see `Procfile`), which declares every exchange, queue and binding in the file.
It is idempotent, so all three services can run it on every deploy, and it fails
the deploy with the object named when the broker disagrees with the file.

**At boot**, the application passively asserts the objects it publishes to and
refuses to start when one is missing — the log names it. Publishes go out with
`mandatory: true`, so a message the broker cannot route comes back and is logged
instead of vanishing.

**Locally**, the broker is a prerequisite: the application will not boot without
it, and neither will `mix test`. It runs in `go-champs-local-infra`:

```bash
docker network create go-champs-shared-network   # once
cd ../go-champs-local-infra && make start
```

The devcontainer joins `go-champs-shared-network` to reach it, so rebuild the
container if it was created before that network was added to
`.devcontainer/docker-compose.yml`.

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix

## Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding features, improving documentation, or suggesting new ideas, your help is appreciated.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

1. Make sure you have Elixir and Phoenix installed
2. Clone the repository
3. Run `mix setup` to install dependencies
4. Start the server with `mix phx.server`

### Issues and Suggestions

If you find a bug or have a suggestion for improvement, please open an issue on GitHub. We appreciate detailed bug reports and feature requests.

### Code of Conduct

Please be respectful and considerate in all interactions. We aim to maintain a welcoming and inclusive environment for all contributors.

---

Thank you for your interest in contributing to GoChampsScoreboard!
