import json
import logging
import time
from collections import Counter, defaultdict

from fastapi import Request

from .errors import APIError, api_error_handler


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return json.dumps(
            {
                "timestamp": self.formatTime(record),
                "level": record.levelname,
                "service": "learning-platform-api",
                "message": record.getMessage(),
                **getattr(record, "fields", {}),
            },
            separators=(",", ":"),
        )


def configure_logging() -> logging.Logger:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    logger = logging.getLogger("learning_platform_api")
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger


class Metrics:
    def __init__(self):
        self.requests = Counter()
        self.latency = defaultdict(list)
        self.events = Counter()

    def observe_request(self, method: str, route: str, status: int, seconds: float) -> None:
        method = (
            method
            if method in {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}
            else "OTHER"
        )
        key = (method, route, str(status // 100))
        self.requests[key] += 1
        values = self.latency[(method, route)]
        values.append(seconds)
        if len(values) > 1000:
            del values[:-1000]

    def increment(self, name: str) -> None:
        self.events[name] += 1

    def render(self) -> str:
        lines = ["# TYPE learning_http_requests_total counter"]
        for (method, route, status), value in sorted(self.requests.items()):
            lines.append(
                f'learning_http_requests_total{{method="{method}",route="{route}",status_class="{status}xx"}} {value}'
            )
        lines.append("# TYPE learning_http_duration_seconds summary")
        for (method, route), values in sorted(self.latency.items()):
            labels = f'method="{method}",route="{route}"'
            # Bounded recent-window latency summary, not a cumulative histogram.
            lines.append(f"learning_http_duration_seconds_sum{{{labels}}} {sum(values)}")
            lines.append(f"learning_http_duration_seconds_count{{{labels}}} {len(values)}")
        lines.append("# TYPE learning_operational_events_total counter")
        for name, value in sorted(self.events.items()):
            lines.append(f'learning_operational_events_total{{event="{name}"}} {value}')
        return "\n".join(lines) + "\n"


async def request_observability(request: Request, call_next):
    start = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception as error:  # noqa: BLE001 - last HTTP boundary, sanitized and logged
        # Exception text can embed SQL parameters or provider payloads. Record
        # the type and correlation ID, never the exception value or request body.
        request.app.state.logger.error(
            "request.failed",
            extra={
                "fields": {
                    "request_id": getattr(request.state, "request_id", None),
                    "exception_type": type(error).__name__,
                }
            },
        )
        response = await api_error_handler(
            request, APIError(500, "INTERNAL_ERROR", "Something went wrong. Please try again.")
        )
    elapsed = time.perf_counter() - start
    route = request.scope.get("route")
    route_path = getattr(route, "path", "unmatched")
    request.app.state.metrics.observe_request(
        request.method, route_path, response.status_code, elapsed
    )
    request.app.state.logger.info(
        "request.completed",
        extra={
            "fields": {
                "environment": request.app.state.settings.environment,
                "request_id": getattr(request.state, "request_id", None),
                "method": request.method,
                "route": route_path,
                "status": response.status_code,
                "latency_ms": round(elapsed * 1000, 2),
            }
        },
    )
    return response


def scrub_error_event(event, hint):
    """Provider-neutral privacy boundary for Sentry's error transport."""
    event.pop("user", None)
    event.pop("request", None)
    event.pop("breadcrumbs", None)
    event.pop("extra", None)
    exception = event.get("exception", {})
    for value in exception.get("values", []):
        value["value"] = "Details redacted; use request ID and exception type."
        for frame in value.get("stacktrace", {}).get("frames", []):
            frame.pop("vars", None)
    return event
