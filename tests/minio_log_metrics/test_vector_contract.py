"""Run production VRL and config in the same pinned image as the Dockerfile."""
from pathlib import Path
import subprocess

import yaml

from tests.containers import container

ROOT = Path(__file__).resolve().parents[2]
IMAGE = "timberio/vector:0.51.1-distroless-static"
CONFIG = ROOT / "docker/minio-log-metrics/vector.yaml"


def vector(config, *args, environment=()):
    options = []
    for entry in environment:
        options.extend(["-e", entry])
    with container(IMAGE, [*args, "/etc/vector/contract.yaml"], {"etc/vector/contract.yaml": yaml.safe_dump(config)}, options) as identifier:
        result = subprocess.run(["docker", "start", "-a", identifier], text=True, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "No tests found" not in result.stdout
        return result.stdout


def case(name, event, accepted):
    test = {"name": name, "inputs": [{"insert_at": "parse_and_route", "type": "log", "log_fields": event}]}
    if accepted:
        test["outputs"] = [{"extract_from": "get_object_accesses", "conditions": [{
            "type": "vrl", "source": '. == {"bucket": "test", "object": "object"}'
        }]}]
    else:
        test["no_outputs_from"] = ["get_object_accesses"]
    return test


def audit(status=None, **extra):
    api = {"name": "GetObject", "bucket": "test", "object": "object"}
    if status is not None:
        api["statusCode"] = status
    return {"api": api, **extra}


def test_no_env_preserves_legacy_getobject_contract():
    config = yaml.safe_load(CONFIG.read_text())
    config["tests"] = [case("missing status still accepted", audit(), True), case("legacy failed GET counted", audit(404), True)]
    vector(config, "test")


def test_success_and_identity_filter_executes_in_pinned_vector():
    config = yaml.safe_load(CONFIG.read_text())
    config["tests"] = [
        case("complete GET", audit(200), True),
        case("range GET string status", audit("206"), True),
        case("not modified", audit(304), False),
        case("missing status fails closed", audit(), False),
        case("not found", audit(404), False),
        case("malformed status", audit("bad"), False),
        # Values are synthetic identity labels, not credentials.
        case("exclude direct identity even with different parent", audit(200, accessKey="test-identity", parentUser="other"), False),
        case("exclude STS parent identity", audit(200, parentUser="test-identity"), False),
        case("other identity accepted", audit(200, parentUser="other"), True),
    ]
    vector(config, "test", environment=("CWM_ACCESS_SUCCESS_ONLY=true", "CWM_TIERER_ACCESS_KEY=test-identity"))


def test_missing_optional_identity_does_not_prevent_startup():
    config = yaml.safe_load(CONFIG.read_text())
    vector(config, "validate", "--no-environment")
    assert config["sources"]["internal_metrics"]["type"] == "internal_metrics"
    assert config["sinks"]["internal_prom_exporter"]["inputs"] == ["internal_metrics"]
    assert config["sinks"]["internal_prom_exporter"]["address"] == "0.0.0.0:9598"
    assert config["sinks"]["prom_exporter"]["inputs"] == ["to_metrics"]
