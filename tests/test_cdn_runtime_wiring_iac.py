from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_cache_admin_wiring_matches_current_cache_nginx_runtime():
    deployment = (REPO_ROOT / "apps/cdn-cache/templates/cache-deployment.yaml").read_text()
    service = (REPO_ROOT / "apps/cdn-cache/templates/cache-service.yaml").read_text()
    values = (REPO_ROOT / "apps/cdn-cache/values.yaml").read_text()

    assert "ENABLE_PURGE_RUNTIME" in deployment
    assert "CWMCDN_CACHE_ADMIN_PORT" in deployment
    assert "CWMCDN_CACHE_ADMIN_TOKEN" in deployment
    assert 'proxy_cache_key "$http_x_cwmcdn_tenant_name$cwmcdn_purge_token$request_uri";' in deployment
    assert "port: 8081" in values
    assert "name: admin" in service
    assert "targetPort: admin" in service


def test_cdn_api_purge_wiring_matches_current_api_runtime():
    deployment = (REPO_ROOT / "apps/cdn-api/templates/cdn-api-deployment.yaml").read_text()
    values = (REPO_ROOT / "apps/cdn-api/values.yaml").read_text()
    api_tf = (REPO_ROOT / "tfmodules/cwm_cdn/api-app.tf").read_text()

    assert "CACHE_PURGE_ENABLED" in deployment
    assert "CACHE_ADMIN_ENDPOINTS" in deployment
    assert "CACHE_ADMIN_BEARER_TOKEN" in deployment
    assert "SECONDARIES_JSON" in deployment
    assert "TRUSTED_CLIENT_IP_ENABLED" in deployment
    assert "CWM_CDN_CACHE_ADMIN_ENDPOINTS" not in deployment
    assert "/internal/purge" not in values
    assert "apiSecondaries.json" in api_tf
    assert "allowedPrimaryKey = var.is_primary ? random_password.primary_key[0].result" in api_tf
