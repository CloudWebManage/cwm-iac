"""Render synthetic objstore examples without providers, state, or cloud credentials."""
import argparse
import json
from pathlib import Path

import yaml

from tests.test_objstore_monitoring import ROOT, evaluate, render, tenant_values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--defaults", action="store_true", help="Render existing policy defaults instead of the opt-in test profile")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    inputs = args.output / "terraform-input"
    inputs.mkdir(exist_ok=True)
    profile = {} if args.defaults else json.loads((ROOT / "docs/examples/objstore-load-test.tfvars.json").read_text())
    config = evaluate(inputs, profile)
    charts = {
        "minio-tenant": tenant_values(config),
        "minio-tenant-metrics": config["metrics"],
        "grafana-dashboards": {"minio": {
            "enabled": True, "objstoreMonitoring": not args.defaults,
            "namespaces": {"tenant": "minio-tenant-test", "metrics": "minio-tenant-test-metrics"},
            "prometheusUrl": "http://minio-tenant-test-metrics-prometheus-server.minio-tenant-test-metrics:80",
        }},
    }
    for chart, values in charts.items():
        docs = render(args.output, chart, values)
        (args.output / f"{chart}.rendered.yaml").write_text(yaml.safe_dump_all(docs))
    print(f"Rendered synthetic chart values and manifests in {args.output}")


if __name__ == "__main__":
    main()
