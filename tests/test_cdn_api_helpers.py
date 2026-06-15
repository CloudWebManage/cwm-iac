from cwm_iac.cdn import api
import pytest


def test_purge_tenant_helper_uses_planned_endpoint_and_selector_body(monkeypatch):
    captured = {}

    def fake_api_request(method, path, **kwargs):
        captured["method"] = method
        captured["path"] = path
        captured["kwargs"] = kwargs
        return {"success": True}

    monkeypatch.setattr(api, "api_request", fake_api_request)

    assert api.purge_tenant(
        "tenant/a",
        paths=["/x?y=1"],
        urls=["https://example.com/x"],
        prefixes=["/assets/"],
        primary=True,
    ) == {"success": True}
    assert captured == {
        "method": "POST",
        "path": "purge?cdn_tenant_name=tenant%2Fa",
        "kwargs": {
            "json": {
                "paths": ["/x?y=1"],
                "urls": ["https://example.com/x"],
                "prefixes": ["/assets/"],
            },
            "primary": True,
            "secondary": False,
        },
    }


def test_purge_tenant_everything_helper_uses_planned_endpoint(monkeypatch):
    captured = {}

    def fake_api_request(method, path, **kwargs):
        captured["method"] = method
        captured["path"] = path
        captured["kwargs"] = kwargs
        return {"success": True}

    monkeypatch.setattr(api, "api_request", fake_api_request)

    assert api.purge_tenant_everything("tenant/a", secondary=True) == {"success": True}
    assert captured == {
        "method": "POST",
        "path": "purge-everything?cdn_tenant_name=tenant%2Fa",
        "kwargs": {"primary": False, "secondary": True},
    }


def test_purge_tenant_helper_rejects_empty_selectors():
    with pytest.raises(ValueError, match="at least one"):
        api.purge_tenant("tenant")
