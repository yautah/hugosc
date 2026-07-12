from __future__ import annotations

from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import json



class WeChatApiError(RuntimeError):
    pass


class WeChatClient:
    base_url = "https://api.weixin.qq.com"

    def __init__(self, app_id: str, app_secret: str) -> None:
        self.app_id = app_id
        self.app_secret = app_secret

    def get_access_token(self) -> str:
        data = _request_json(
            "GET",
            f"{self.base_url}/cgi-bin/token?{urlencode({
                "grant_type": "client_credential",
                "appid": self.app_id,
                "secret": self.app_secret,
            })}",
        )
        if "access_token" not in data:
            raise WeChatApiError(f"WeChat token request failed: {data}")
        return str(data["access_token"])

    def upload_article_image(self, access_token: str, image_path: Path) -> str:
        data = _multipart_post(
            f"{self.base_url}/cgi-bin/media/uploadimg?{urlencode({'access_token': access_token})}",
            image_path,
        )
        if "url" not in data:
            raise WeChatApiError(f"WeChat article image upload failed for {image_path}: {data}")
        return str(data["url"])

    def add_permanent_image_material(self, access_token: str, image_path: Path) -> str:
        data = _multipart_post(
            f"{self.base_url}/cgi-bin/material/add_material?{urlencode({'access_token': access_token, 'type': 'image'})}",
            image_path,
        )
        if "media_id" not in data:
            raise WeChatApiError(f"WeChat cover material upload failed for {image_path}: {data}")
        return str(data["media_id"])

    def add_draft(self, access_token: str, payload: dict[str, Any]) -> dict[str, Any]:
        data = _request_json(
            "POST",
            f"{self.base_url}/cgi-bin/draft/add?{urlencode({'access_token': access_token})}",
            json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            {"Content-Type": "application/json; charset=utf-8"},
        )
        if data.get("errcode"):
            raise WeChatApiError(f"WeChat draft creation failed: {data}")
        return data


def _mime_type(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if suffix == ".png":
        return "image/png"
    if suffix == ".gif":
        return "image/gif"
    return "application/octet-stream"


def _request_json(method: str, url: str, body: bytes | None = None, headers: dict[str, str] | None = None) -> dict[str, Any]:
    request = Request(url, data=body, headers=headers or {}, method=method)
    with urlopen(request, timeout=60) as response:
        raw = response.read().decode("utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise WeChatApiError(f"WeChat returned non-JSON response: {raw[:200]}") from exc
    return data


def _multipart_post(url: str, image_path: Path) -> dict[str, Any]:
    boundary = "----ContentPublisherBoundary7MA4YWxkTrZu0gW"
    file_bytes = image_path.read_bytes()
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="media"; filename="{image_path.name}"\r\n'
        f"Content-Type: {_mime_type(image_path)}\r\n\r\n"
    ).encode("utf-8")
    tail = f"\r\n--{boundary}--\r\n".encode("utf-8")
    return _request_json("POST", url, head + file_bytes + tail, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
