import uuid

from fastapi import Request
from fastapi.responses import JSONResponse


class APIError(Exception):
    def __init__(self, status: int, code: str, message: str, field: str | None = None):
        self.status, self.code, self.message, self.field = status, code, message, field


async def api_error_handler(request: Request, exc: APIError) -> JSONResponse:
    request.state.error_code = exc.code
    if exc.__cause__ is not None:
        request.state.error_cause_type = type(exc.__cause__).__name__
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    error = {"code": exc.code, "message": exc.message, "requestId": request_id}
    if exc.field:
        error["field"] = exc.field
    return JSONResponse(
        status_code=exc.status, content={"error": error}, headers={"X-Request-ID": request_id}
    )


async def validation_error_handler(request: Request, exc) -> JSONResponse:
    # Never echo Pydantic input/context: it can contain passwords and reset tokens.
    return await api_error_handler(
        request, APIError(422, "VALIDATION_FAILED", "Please check the information you entered.")
    )


async def http_error_handler(request: Request, exc) -> JSONResponse:
    return await api_error_handler(
        request,
        APIError(
            exc.status_code,
            "NOT_FOUND" if exc.status_code == 404 else "REQUEST_REJECTED",
            "The requested resource is unavailable.",
        ),
    )
