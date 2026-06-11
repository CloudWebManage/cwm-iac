from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_cdn_edge_routes_http_and_acme_challenge_paths():
    configmap = (REPO_ROOT / "apps/cdn-edge/templates/configmap.yaml").read_text()

    assert "listen 80;" in configmap
    assert "location ^~ /.well-known/acme-challenge/" in configmap
    assert "proxy_set_header Host $host;" in configmap
    assert "{{ .Values.acmeHttp01.upstreamHost }}:{{ .Values.acmeHttp01.upstreamPort }}" in configmap
    assert "proxy_pass http://$host:80;" in configmap


def test_cdn_edge_secondary_acme_upstream_uses_primary_edge_hostname():
    edge_app_tf = (REPO_ROOT / "tfmodules/cwm_cdn/edge-app.tf").read_text()

    assert 'var.is_primary ? "acme-ingress-upstream.kube-system.svc.cluster.local"' in edge_app_tf
    assert '"edge.${var.allowed_primary_cluster_name}.${var.zone_domain}"' in edge_app_tf


def test_tenant_cert_cluster_issuer_uses_http01_solver():
    cert_manager_tf = (REPO_ROOT / "tfmodules/cwm_cdn/tenant_certs.tf").read_text()

    assert "name: cdn-tenant-certs" in cert_manager_tf
    assert "http01:" in cert_manager_tf
    assert "class: nginx" in cert_manager_tf
