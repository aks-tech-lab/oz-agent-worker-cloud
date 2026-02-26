# Copilot instructions for oz-agent-worker

## Project overview
- Self-hosted worker daemon that connects to Warp (Oz) via WebSocket, claims tasks, and launches agent runs inside Docker containers.
- Core flow: main.go parses CLI -> worker.New() validates Docker + platform -> worker.Start() manages WS reconnect/loops -> handleTaskAssignment -> executeTaskInDocker.
- Task execution always mounts a sidecar image filesystem into /agent so the runtime is injected into the task container.

## Architecture and data flow
- WebSocket wire types live in internal/types/messages.go; only task_assignment is handled today (worker replies with task_claimed or task_failed).
- Connection lifecycle uses ping/pong heartbeat + exponential reconnect backoff in internal/worker/worker.go.
- Task start flow (internal/worker/worker.go): resolve task image (assignment.DockerImage or default ubuntu:22.04), pull with registry auth, ensure platform linux/amd64 or linux/arm64.
- Sidecar volumes are keyed by image digest; the sidecar filesystem is exported to a Docker volume and reused across tasks.
- Additional sidecars (types.SidecarMount) are also exported to volumes and mounted at their mount paths (unique per task, read-only unless ReadWrite=true).

## Container command and args
- Container command is /agent/entrypoint.sh agent run --share team:edit --task-id <id> --sandboxed --server-root-url <url>.
- internal/common/task_utils.go augments args from AgentConfigSnapshot (model/profile/skill/mcp/computer-use/environment) and always appends --idle-on-complete.

## Conventions and patterns
- CLI -e/--env accepts KEY=VALUE or bare KEY to passthrough host env (parseEnvFlags in main.go).
- Task env precedence: assignment.EnvVars are added first, then CLI envs override.
- Logging uses internal/log (zerolog) with global level from --log-level; debug logging prints container logs on success, info on failure.
- Cleanup: task containers are removed unless --no-cleanup is set; sidecar volumes are intentionally reused.

## Developer workflows
- Build: go build -o oz-agent-worker (see README).
- Run: ./oz-agent-worker --api-key "wk-..." --worker-id "my-worker" [-e KEY=VALUE] [-v HOST:CONTAINER].
- Docker usage requires mounting /var/run/docker.sock into the worker container (README).

## External dependencies
- Docker daemon must be reachable (client.FromEnv + Ping) or worker startup fails.
- WebSocket endpoint defaults to wss://oz.warp.dev/api/v1/selfhosted/worker/ws; server root defaults to https://app.warp.dev (hidden CLI overrides).

## Files to start with
- main.go (CLI and worker wiring)
- internal/worker/worker.go (WebSocket + Docker task execution)
- internal/common/task_utils.go (agent CLI args from config)
- internal/types/messages.go (wire formats)
