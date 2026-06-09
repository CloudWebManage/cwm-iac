from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_cdn_edge_routes_http_and_acme_challenge_paths():
    configmap = (REPO_ROOT / "apps/cdn-edge/templates/configmap.yaml").read_text()

    assert "listen 80;" in configmap
    assert "location ^~ /.well-known/acme-challenge/" in configmap
    assert "proxy_set_header Host $host;" in configmap
    assert "rke2-ingress-nginx-controller.kube-system.svc.cluster.local:80" in configmap
    assert "proxy_pass http://$host:80;" in configmap


def test_cert_manager_has_cdn_http01_solver_selector():
    cert_manager_tf = (REPO_ROOT / "tfmodules/cluster_k8s_apps/cert-manager.tf").read_text()

    assert '"cdn.cloudwm-cdn.com/acme-http01-solver" = "true"' in cert_manager_tf
    assert "http01 = {" in cert_manager_tf
    assert 'ingressClassName: "nginx"' in cert_manager_tf
