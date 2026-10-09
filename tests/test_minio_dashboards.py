"""Rendered dashboards must match the deployed v2 scrape contract."""
import json
from pathlib import Path
import re
import subprocess

import pytest
import yaml

ROOT=Path(__file__).resolve().parents[1]
TITLES={"MinIO Bucket Analytics", "MinIO RED Metrics", "MinIO Storage & Capacity", "MinIO Cluster Health"}

@pytest.fixture(scope="module")
def dashboards():
    result=subprocess.run(["helm","template","test",str(ROOT/"apps/grafana-dashboards"),
        "--set","minio.enabled=true","--set","minio.prometheusUrl=http://example:80"],
        capture_output=True,text=True,check=True)
    dashboards={}
    for cm in yaml.safe_load_all(result.stdout):
        if not cm or cm.get("metadata",{}).get("labels",{}).get("grafana_dashboard")!="1":continue
        for raw in cm.get("data",{}).values():
            d=json.loads(raw);dashboards[d["title"]]=d
    return dashboards


def texts(value):
    if isinstance(value,str):yield value
    elif isinstance(value,dict):
        for item in value.values():yield from texts(item)
    elif isinstance(value,list):
        for item in value:yield from texts(item)


@pytest.mark.parametrize("title",sorted(TITLES))
def test_dashboard_metrics_exist_in_observed_v2_contract(dashboards,title):
    available=set(json.loads((ROOT/"tests/fixtures/minio-v2-metric-names.json").read_text()))
    required={m for text in texts(dashboards[title]) for m in re.findall(r"\bminio_[a-zA-Z0-9_:]+",text)}
    assert required <= available, sorted(required-available)
    assert not any("by (name)" in text or 'name=~' in text for text in texts(dashboards[title]))


def test_provisioned_debugging_dashboard_has_real_datasource_variables_and_relative_time(dashboards):
    d=dashboards["Minio Debugging"]
    assert d["time"]=={"from":"now-1h","to":"now"}
    assert not d.get("__inputs")
    variables={v["name"] for v in d["templating"]["list"] if v["type"]=="datasource"}
    refs={m for text in texts(d) for m in re.findall(r"\$\{(DS_[A-Z_]+)\}",text)}
    assert not refs
    assert {"datasource","ingress_datasource"} <= variables


def test_offline_drive_count_is_not_rendered_as_old_health_enum(dashboards):
    panel=next(p for p in dashboards['MinIO Storage & Capacity']['panels'] if p.get('title')=='Offline Drives by Node')
    defaults=panel['fieldConfig']['defaults']
    assert defaults['mappings']==[]
    assert defaults['unit']=='short'
    assert defaults['thresholds']['steps']==[{'color':'green','value':None},{'color':'red','value':1}]
